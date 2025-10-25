// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.19;

/*
  Chrono Stability Pool (Solidity)
  Inspired by Liquity's Stability Pool concept but simplified and adapted
  for Chrono's needs. This contract holds stablecoins deposited by providers.
  During liquidations the protocol calls `offsetDebt` supplying the amount of
  debt to cancel and the collateral seized from the borrower. The contract:
    - absorbs the debt by proportionally reducing depositor's stable balances
      (done by manipulating a global scaling factor `P` so reduction is O(1)),
    - credits collateral proportionally to depositors via a cumulative
      `C` (collateral per effective unit) so claimable collateral is computed
      in O(1) per user,
    - lets depositors deposit / withdraw stable tokens and claim collateral.

  Important design notes:
    - `rawDeposit` stores a user's "raw" share. Effective balance = raw * P / RAY.
    - When debt is offset, we compute a multiplicative factor and update P.
      This causes all effective balances to shrink proportionally without loops.
    - `C` is the cumulative collateral-per-effective-unit (scaled by RAY).
    - When distribution happens, C += collateralAmount * RAY / totalEffectiveBefore.
    - On deposit/withdraw/claim we update per-user snapshots to settle gains.

  This is a foundation implementation. For production you should:
    - Run thorough audits and tests (unit + property-based),
    - Add checkpointing for gas-heavy operations if needed,
    - Consider multiple stable tokens / collateral types,
    - Add events for analytics and off-chain indexing,
    - Add emergency shutdown / governance controls as required.
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ChronoStabilityPool is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // --- Constants ---
    uint256 private constant RAY = 1e18; // scaling factor for fixed point

    // --- Tokens ---
    IERC20 public immutable stableToken;     // e.g. USDC, LUSD (18-dec assumed)
    IERC20 public immutable collateralToken; // asset returned to depositors on liquidation

    // --- State (global accounting) ---
    // P: global scaling factor converting rawDeposits -> effective deposits
    // EffectiveDeposit = rawDeposit * P / RAY
    uint256 public P; // starts at RAY

    // C: cumulative collateral (in collateralToken) per *effective* stable unit, scaled by RAY
    // When collateral is distributed, C increases by (collateralAmount * RAY / totalEffective)
    uint256 public C;

    // totalRaw: sum of rawDeposit for all users
    uint256 public totalRaw;

    // Address of the Chrono lending core (allowed to call offsetDebt)
    address public protocol; 

    // --- Per-user data ---
    struct Depositor {
        uint256 raw;           // raw share units
        uint256 collateralSnapshot; // snapshot of C at last update
        uint256 pendingCollateral;   // stored collateral amounts ready to claim
    }

    mapping(address => Depositor) public depositors;

    // --- Events ---
    event Deposit(address indexed user, uint256 amount, uint256 rawAdded);
    event Withdraw(address indexed user, uint256 amount, uint256 rawRemoved);
    event CollateralClaimed(address indexed user, uint256 amount);
    event OffsetExecuted(address indexed caller, uint256 debtCovered, uint256 collateralReceived);
    event ProtocolSet(address indexed protocol);

    // --- Modifiers ---
    modifier onlyProtocol() {
        require(msg.sender == protocol, "Not protocol");
        _;
    }

    constructor(address _stableToken, address _collateralToken, address _protocol)
    Ownable(msg.sender) {
        require(_stableToken != address(0) && _collateralToken != address(0), "zero token");
        stableToken = IERC20(_stableToken);
        collateralToken = IERC20(_collateralToken);
        protocol = _protocol;

        P = RAY;
        C = 0;
    }

    // Governance: set protocol contract allowed to call offset
    function setProtocol(address _protocol) external onlyOwner {
        protocol = _protocol;
        emit ProtocolSet(_protocol);
    }

    // --- Public view helpers ---
    // Effective/current deposit of a user (what they'd get back if no offsets happen)
    function effectiveBalanceOf(address user) public view returns (uint256) {
        Depositor storage d = depositors[user];
        return (d.raw * P) / RAY;
    }

    // Total effective supply of stable tokens in the pool
    function totalEffectiveSupply() public view returns (uint256) {
        return (totalRaw * P) / RAY;
    }

    // Collateral claimable by user according to accumulated C
    function claimableCollateralOf(address user) public view returns (uint256) {
        Depositor storage d = depositors[user];
        // effective balance uses current P
        uint256 effective = (d.raw * P) / RAY;
        uint256 deltaC = C - d.collateralSnapshot; // scaled by RAY
        uint256 gain = (effective * deltaC) / RAY; // collateral units
        return d.pendingCollateral + gain;
    }

    // --- Mutating user actions ---

    // Deposit stable tokens into the pool
    // `amount` is in stableToken units (assumed same decimals across usage)
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "amount>0");
        address user = msg.sender;

        // If pool was emptied (P==0) we re-initialize P to RAY so newly deposited amounts
        // get fresh accounting. No prior holders remain when P==0.
        if (P == 0) {
            // Resetting P to RAY means raw units == stable units for new deposits
            P = RAY;
        }

        // first settle user's pending collateral gains
        _updateUserGains(user);

        // compute raw units to add so effective increases exactly by `amount`:
        // rawAdded * P / RAY = amount  => rawAdded = amount * RAY / P
        uint256 rawAdded = (amount * RAY) / P;
        require(rawAdded > 0, "rawAdded==0");

        // pull stable tokens
        stableToken.safeTransferFrom(user, address(this), amount);

        depositors[user].raw += rawAdded;
        totalRaw += rawAdded;

        // set collateral snapshot to current C for this depositor (they start earning from now)
        depositors[user].collateralSnapshot = C;

        emit Deposit(user, amount, rawAdded);
    }

    // Withdraw stable tokens up to your effective balance (claims collateral first)
    function withdraw(uint256 amount) external nonReentrant {
        address user = msg.sender;
        require(amount > 0, "amount>0");

        // claim collateral first (so user's snapshots are up to date)
        _updateUserGains(user);

        uint256 effective = (depositors[user].raw * P) / RAY;
        require(amount <= effective, "insufficient balance");

        // compute raw to remove: rawRemove * P / RAY = amount
        uint256 rawRemove = (amount * RAY) / P;

        // adjust accounting
        depositors[user].raw -= rawRemove;
        totalRaw -= rawRemove;

        // ensure user's collateral snapshot is updated to current C (done in _updateUserGains)
        stableToken.safeTransfer(user, amount);

        emit Withdraw(user, amount, rawRemove);
    }

    // Claim accrued collateral rewards (from previous liquidations)
    function claimCollateral() external nonReentrant {
        address user = msg.sender;
        _updateUserGains(user);

        uint256 toClaim = depositors[user].pendingCollateral;
        require(toClaim > 0, "no collateral");

        depositors[user].pendingCollateral = 0;
        collateralToken.safeTransfer(user, toClaim);

        emit CollateralClaimed(user, toClaim);
    }

    // Internal: settle user's gain and update snapshot
    function _updateUserGains(address user) internal {
        Depositor storage d = depositors[user];
        if (d.raw == 0) {
            // still update snapshot so future gains are measured from now
            d.collateralSnapshot = C;
            return;
        }
        uint256 effective = (d.raw * P) / RAY;
        uint256 deltaC = C - d.collateralSnapshot; // scaled by RAY
        if (deltaC > 0) {
            uint256 gain = (effective * deltaC) / RAY;
            d.pendingCollateral += gain;
        }
        d.collateralSnapshot = C;
    }

    // --- Protocol actions (called by the lending core during liquidation) ---
    // debtToCover: amount of stable debt to cancel (in stableToken units)
    // collateralAmount: amount of collateral seized from borrower to distribute (in collateralToken units)
    // Effects:
    //  - reduces effective supply proportionally by debtCovered
    //  - increases C so collateral is distributed to depositors

    function offsetDebt(uint256 debtToCover, uint256 collateralAmount) external nonReentrant onlyProtocol {
        require(debtToCover > 0, "debt>0");
        uint256 totalEffective = totalEffectiveSupply();
        require(totalEffective > 0, "empty pool");

        uint256 debtCovered = debtToCover;
        if (debtCovered >= totalEffective) {
            // Entire pool will be consumed. We will set P=0 (everyone's effective becomes 0)
            debtCovered = totalEffective;
        }

        // 1) Distribute collateral proportionally to current effective units.
        // deltaC = collateralAmount / totalEffective
        if (collateralAmount > 0) {
            // transfer collateral from caller (protocol) into this contract
            collateralToken.safeTransferFrom(msg.sender, address(this), collateralAmount);

            // increment C by collateral per effective unit (scaled)
            // avoid division by zero; totalEffective>0
            uint256 deltaC = (collateralAmount * RAY) / totalEffective;
            C += deltaC;
        }

        // 2) Reduce effective balances by multiplicative factor
        // newEffectiveTotal = totalEffective - debtCovered
        // factor = newEffectiveTotal / totalEffective
        if (debtCovered == totalEffective) {
            // pool emptied
            P = 0;
            // Note: totalRaw remains as historical raw units; when P==0, effective = 0
        } else {
            // factor = (totalEffective - debtCovered) / totalEffective
            // P := P * factor
            uint256 numerator = (totalEffective - debtCovered) * RAY;
            uint256 denominator = totalEffective;
            uint256 factor = numerator / denominator; // scaled by RAY
            P = (P * factor) / RAY;
        }

        emit OffsetExecuted(msg.sender, debtCovered, collateralAmount);
    }

    // --- Emergency / admin helpers ---
    // Allow owner to recover tokens accidentally sent (not protocol funds). Use with extreme caution.
    function recoverERC20(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "zero to");
        IERC20(token).safeTransfer(to, amount);
    }

}
