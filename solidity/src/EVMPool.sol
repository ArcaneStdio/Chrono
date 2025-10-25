// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.19;

/*
  Minimal Stability Pool (Solidity)

  Purpose:
  - Simple on-EVM deposit pool for locking stable tokens.
  - Supports proportional loss application (offsetDebt) via a global scale P.
  - Designed to be used with an external bridge/protocol that will mint wrapped tokens on Flow/Cadence.
  - No collateral accounting or Stability-Pool-specific features are present here (those live on Flow/Cadence).

  Notes:
  - All amounts denominated in token units (stableToken).
  - RAY fixed-point (1e18) used for scaling to preserve precision.
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MinimalStabilityPool is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    uint256 private constant RAY = 1e18;

    IERC20 public immutable stableToken;

    // Global scaling factor for raw->effective; start = RAY (i.e., 1:1)
    uint256 public P;

    // sum of raw deposit shares
    uint256 public totalRaw;

    // protocol/bridge address allowed to call offsetDebt
    address public protocol;

    struct Depositor {
        uint256 raw; // raw share units
    }

    mapping(address => Depositor) public depositors;

    event Deposit(address indexed user, uint256 amount, uint256 rawAdded);
    event Withdraw(address indexed user, uint256 amount, uint256 rawRemoved);
    event OffsetExecuted(address indexed caller, uint256 debtCovered);
    event ProtocolSet(address indexed protocol);

    modifier onlyProtocol() {
        require(msg.sender == protocol, "Not protocol");
        _;
    }

    constructor(address _stableToken, address _protocol) {
        require(_stableToken != address(0), "zero token");
        stableToken = IERC20(_stableToken);
        protocol = _protocol;

        P = RAY;
        totalRaw = 0;
    }

    function setProtocol(address _protocol) external onlyOwner {
        protocol = _protocol;
        emit ProtocolSet(_protocol);
    }

    // --- Views ---

    function rawToEffective(uint256 raw) public view returns (uint256) {
        return (raw * P) / RAY;
    }

    function effectiveToRaw(uint256 effective) public view returns (uint256) {
        require(P > 0, "P==0");
        return (effective * RAY) / P;
    }

    function effectiveBalanceOf(address user) external view returns (uint256) {
        return rawToEffective(depositors[user].raw);
    }

    function totalEffectiveSupply() public view returns (uint256) {
        return rawToEffective(totalRaw);
    }

    // --- User actions ---

    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "amount>0");
        address user = msg.sender;

        // Reinitialize P if emptied (defensive)
        if (P == 0) {
            P = RAY;
        }

        // rawAdded such that rawAdded * P / RAY == amount
        uint256 rawAdded = (amount * RAY) / P;
        require(rawAdded > 0, "rawAdded==0");

        stableToken.safeTransferFrom(user, address(this), amount);

        depositors[user].raw += rawAdded;
        totalRaw += rawAdded;

        emit Deposit(user, amount, rawAdded);
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "amount>0");
        address user = msg.sender;

        uint256 effective = rawToEffective(depositors[user].raw);
        require(amount <= effective, "insufficient balance");

        uint256 rawRemove = (amount * RAY) / P;
        // handle rounding edge-case: if rawRemove > user's raw due to rounding, clamp
        if (rawRemove > depositors[user].raw) {
            rawRemove = depositors[user].raw;
        }

        depositors[user].raw -= rawRemove;
        totalRaw -= rawRemove;

        stableToken.safeTransfer(user, amount);

        emit Withdraw(user, amount, rawRemove);
    }

    // --- Protocol action: apply an offset (take funds out of pool) ---
    // The protocol/bridge calls this to withdraw `debtToCover` from the pool proportionally.
    // The pool transfers `debtCovered` tokens to the protocol address and updates P so remaining
    // depositors' effective balances shrink proportionally.
    function offsetDebt(uint256 debtToCover) external nonReentrant onlyProtocol {
        require(debtToCover > 0, "debt>0");

        uint256 totalEffective = rawToEffective(totalRaw);
        require(totalEffective > 0, "empty pool");

        uint256 debtCovered = debtToCover;
        if (debtCovered >= totalEffective) {
            // drain everything
            debtCovered = totalEffective;
        }

        // Transfer the actual tokens corresponding to debtCovered to protocol address.
        // If draining entire pool, transfer contract token balance (defensive in case P drift).
        if (debtCovered == totalEffective) {
            uint256 bal = stableToken.balanceOf(address(this));
            if (bal > 0) {
                stableToken.safeTransfer(protocol, bal);
            }
            // set P to 0 so future effective balances become zero until new deposits
            P = 0;
            totalRaw = totalRaw; // keep raw as-is; rawToEffective will return 0 while P==0
        } else {
            // Proportional shrink: compute multiplicative factor and apply to P.
            // factor = (totalEffective - debtCovered) / totalEffective  (scaled by RAY)
            uint256 numerator = (totalEffective - debtCovered) * RAY;
            uint256 denominator = totalEffective;
            uint256 factor = numerator / denominator; // scaled by RAY

            P = (P * factor) / RAY;

            // Transfer the exact amount of tokens that correspond to debtCovered
            stableToken.safeTransfer(protocol, debtCovered);
        }

        emit OffsetExecuted(msg.sender, debtCovered);
    }

    // Emergency / admin: recover accidentally sent ERC20s (owner)
    function recoverERC20(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "zero to");
        IERC20(token).safeTransfer(to, amount);
    }
}
