// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.19;

/*
  Chrono Stability Pool (Solidity) - corrected C accounting (per-raw-unit)

  Key fix:
  - C is now cumulative collateral **per raw unit** (scaled by RAY).
    This makes collateral distribution independent of P updates (offsets),
    ensuring gains are computed correctly even after P changes.

  Other notes:
  - totalDeposits stores effective units (as requested).
  - totalRaw stores raw units; raw -> effective uses P.
  - All math uses RAY = 1e18 fixed point.
*/
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StabilityPool is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    uint256 private constant RAY = 1e18;

    IERC20 public immutable stableToken;
    IERC20 public immutable collateralToken;

    // Global scaling for raw -> effective
    uint256 public P;

    // C: cumulative collateral **per raw unit**, scaled by RAY.
    // When collateralAmount is distributed, C += (collateralAmount * RAY) / totalRaw
    uint256 public C;

    // sum of raw deposits
    uint256 public totalRaw;

    // effective total deposits (in stable token units), stored in state as requested
    uint256 public totalDeposits;

    address public protocol;

    struct Depositor {
        uint256 raw;             // raw share units
        uint256 collateralSnapshot; // snapshot of C at last update (RAY-scaled)
        uint256 pendingCollateral;   // collateral units awaiting claim
    }

    mapping(address => Depositor) public depositors;

    event Deposit(address indexed user, uint256 amount, uint256 rawAdded);
    event Withdraw(address indexed user, uint256 amount, uint256 rawRemoved);
    event CollateralClaimed(address indexed user, uint256 amount);
    event OffsetExecuted(address indexed caller, uint256 debtCovered, uint256 collateralReceived);
    event ProtocolSet(address indexed protocol);

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
        totalRaw = 0;
        totalDeposits = 0;
    }

    function setProtocol(address _protocol) external onlyOwner {
        protocol = _protocol;
        emit ProtocolSet(_protocol);
    }

    // --- Helpers ---

    function rawToEffective(uint256 raw) public view returns (uint256) {
        return (raw * P) / RAY;
    }

    function effectiveToRaw(uint256 effective) public view returns (uint256) {
        require(P > 0, "P==0");
        return (effective * RAY) / P;
    }

    function effectiveBalanceOf(address user) public view returns (uint256) {
        return rawToEffective(depositors[user].raw);
    }

    function totalEffectiveSupply() public view returns (uint256) {
        return rawToEffective(totalRaw);
    }

    /// Claimable collateral computed using raw units and per-raw-unit C.
    function claimableCollateralOf(address user) public view returns (uint256) {
        Depositor storage d = depositors[user];
        uint256 deltaC = C - d.collateralSnapshot; // scaled by RAY
        uint256 gain = (d.raw * deltaC) / RAY; // collateral units
        return d.pendingCollateral + gain;      
    }

    // --- User actions ---

    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "amount>0");
        address user = msg.sender;

        // Reinitialize P if emptied
        if (P == 0) {
            P = RAY;
        }

        // settle gains up to now
        _updateUserGains(user);

        // rawAdded so effective increases by amount: rawAdded * P / RAY = amount
        uint256 rawAdded = (amount * RAY) / P;
        require(rawAdded > 0, "rawAdded==0");

        stableToken.safeTransferFrom(user, address(this), amount);

        depositors[user].raw += rawAdded;
        totalRaw += rawAdded;

        // update effective stored total by the nominal amount
        totalDeposits += amount;

        // snapshot current per-raw C
        depositors[user].collateralSnapshot = C;

        emit Deposit(user, amount, rawAdded);
    }

    function withdraw(uint256 amount) external nonReentrant {
        address user = msg.sender;
        require(amount > 0, "amount>0");

        _updateUserGains(user);

        uint256 effective = rawToEffective(depositors[user].raw);
        require(amount <= effective, "insufficient balance");

        uint256 rawRemove = (amount * RAY) / P;

        depositors[user].raw -= rawRemove;
        totalRaw -= rawRemove;

        totalDeposits -= amount;

        stableToken.safeTransfer(user, amount);

        emit Withdraw(user, amount, rawRemove);
    }

    function claimCollateral() external nonReentrant {
        address user = msg.sender;
        _updateUserGains(user);

        uint256 toClaim = depositors[user].pendingCollateral;
        require(toClaim > 0, "no collateral");

        depositors[user].pendingCollateral = 0;
        collateralToken.safeTransfer(user, toClaim);

        emit CollateralClaimed(user, toClaim);
    }

    function _updateUserGains(address user) internal {
        Depositor storage d = depositors[user];

        if (d.raw == 0) {
            d.collateralSnapshot = C;
            return;
        }

        uint256 deltaC = C - d.collateralSnapshot; // per-raw delta
        if (deltaC > 0) {
            uint256 gain = (d.raw * deltaC) / RAY;
            d.pendingCollateral += gain;
        }
        d.collateralSnapshot = C;
    }

    // --- Protocol / Liquidation ---

    function offsetDebt(uint256 debtToCover, uint256 collateralAmount) external nonReentrant onlyProtocol {
        require(debtToCover > 0, "debt>0");
        // total effective before (used only for comparisons). We derive debtCover cap from effective.
        uint256 totalEffective = rawToEffective(totalRaw);
        require(totalEffective > 0, "empty pool");

        uint256 debtCovered = debtToCover;
        if (debtCovered >= totalEffective) {
            debtCovered = totalEffective;
        }

        // 1) Distribute collateral proportionally to raw units
        // Use totalRaw (raw units) to make distribution independent of P.
        if (collateralAmount > 0) {
            require(totalRaw > 0, "no raw supply");
            // Pull collateral from protocol (msg.sender)
            collateralToken.safeTransferFrom(msg.sender, address(this), collateralAmount);

            // deltaC per raw unit:
            uint256 deltaC = (collateralAmount * RAY) / totalRaw;
            C += deltaC;
        }

        // 2) Reduce effective balances by multiplicative factor
        if (debtCovered == totalEffective) {
            // emptied
            P = 0;
            totalDeposits = 0;
            // totalRaw kept as-is (rawToEffective yields 0)
        } else {
            uint256 numerator = (totalEffective - debtCovered) * RAY;
            uint256 denominator = totalEffective;
            uint256 factor = numerator / denominator; // scaled by RAY

            P = (P * factor) / RAY;

            // scale stored effective total
            totalDeposits = (totalDeposits * factor) / RAY;
        }

        emit OffsetExecuted(msg.sender, debtCovered, collateralAmount);
    }

    // Admin token recovery
    function recoverERC20(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "zero to");
        IERC20(token).safeTransfer(to, amount);
    }
}
