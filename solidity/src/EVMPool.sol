// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.19;

/*
  Chrono Multi-Pool Stability (Solidity)

  - Supports multiple stable-token pools on one contract.
  - Each pool (identified by stable token address) has its own:
      P (raw->effective scaler), C (collateral per raw unit), totalRaw, totalDeposits, collateralToken.
  - deposit/withdraw/claimCollateral/offsetDebt accept a pool token parameter.
  - addPool lets owner register which stable tokens are supported and the corresponding collateral token.
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StabilityPoolMulti is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    uint256 private constant RAY = 1e18;

    // Pool state per stable token address
    mapping(address => uint256) public P; // scaled by RAY; raw -> effective: raw * P / RAY
    mapping(address => uint256) public C; // cumulative collateral per raw unit (scaled by RAY)
    mapping(address => uint256) public totalRaw; // sum raw shares per pool
    mapping(address => uint256) public totalDeposits; // effective-token-units (stored nominally)
    mapping(address => address) public collateralOf; // stableToken => collateralToken
    mapping(address => bool) public poolExists;

    // depositors[stableToken][user]
    struct Depositor {
        uint256 raw;
        uint256 collateralSnapshot; // scaled by RAY
        uint256 pendingCollateral;
    }
    mapping(address => mapping(address => Depositor)) public depositors;

    address public protocol; // allowed to call offsetDebt

    event PoolAdded(address indexed stableToken, address indexed collateralToken);
    event Deposit(address indexed poolToken, address indexed user, uint256 amount, uint256 rawAdded);
    event Withdraw(address indexed poolToken, address indexed user, uint256 amount, uint256 rawRemoved);
    event CollateralClaimed(address indexed poolToken, address indexed user, uint256 amount);
    event OffsetExecuted(address indexed poolToken, address indexed caller, uint256 debtCovered, uint256 collateralReceived);
    event ProtocolSet(address indexed protocol);

    modifier onlyProtocol() {
        require(msg.sender == protocol, "Not protocol");
        _;
    }

    constructor(address _protocol) {
        protocol = _protocol;
    }

    function setProtocol(address _protocol) external onlyOwner {
        protocol = _protocol;
        emit ProtocolSet(_protocol);
    }

    // Admin: register a new stable token pool and its collateral token
    function addPool(address stableToken, address collateralToken) external onlyOwner {
        require(stableToken != address(0), "zero stable");
        require(collateralToken != address(0), "zero collateral");
        require(!poolExists[stableToken], "pool exists");

        poolExists[stableToken] = true;
        collateralOf[stableToken] = collateralToken;

        // initialize scalers
        P[stableToken] = RAY;
        C[stableToken] = 0;
        totalRaw[stableToken] = 0;
        totalDeposits[stableToken] = 0;

        emit PoolAdded(stableToken, collateralToken);
    }

    // --- Helpers per pool ---

    function rawToEffective(address poolToken, uint256 raw) public view returns (uint256) {
        return (raw * P[poolToken]) / RAY;
    }

    function effectiveToRaw(address poolToken, uint256 effective) public view returns (uint256) {
        require(P[poolToken] > 0, "P==0");
        return (effective * RAY) / P[poolToken];
    }

    function effectiveBalanceOf(address poolToken, address user) external view returns (uint256) {
        return rawToEffective(poolToken, depositors[poolToken][user].raw);
    }

    function totalEffectiveSupply(address poolToken) public view returns (uint256) {
        return rawToEffective(poolToken, totalRaw[poolToken]);
    }

    function claimableCollateralOf(address poolToken, address user) public view returns (uint256) {
        Depositor storage d = depositors[poolToken][user];
        uint256 deltaC = C[poolToken] - d.collateralSnapshot; // scaled by RAY
        uint256 gain = (d.raw * deltaC) / RAY;
        return d.pendingCollateral + gain;
    }

    // --- User actions ---

    function deposit(address poolToken, uint256 amount) external nonReentrant {
        require(poolExists[poolToken], "pool not registered");
        require(amount > 0, "amount>0");
        address user = msg.sender;

        // Reinit P if emptied
        if (P[poolToken] == 0) {
            P[poolToken] = RAY;
        }

        _updateUserGains(poolToken, user);

        uint256 rawAdded = (amount * RAY) / P[poolToken];
        require(rawAdded > 0, "rawAdded==0");

        IERC20(poolToken).safeTransferFrom(user, address(this), amount);

        depositors[poolToken][user].raw += rawAdded;
        totalRaw[poolToken] += rawAdded;

        totalDeposits[poolToken] += amount;

        depositors[poolToken][user].collateralSnapshot = C[poolToken];

        emit Deposit(poolToken, user, amount, rawAdded);
    }

    function withdraw(address poolToken, uint256 amount) external nonReentrant {
        require(poolExists[poolToken], "pool not registered");
        require(amount > 0, "amount>0");
        address user = msg.sender;

        _updateUserGains(poolToken, user);

        uint256 effective = rawToEffective(poolToken, depositors[poolToken][user].raw);
        require(amount <= effective, "insufficient balance");

        uint256 rawRemove = (amount * RAY) / P[poolToken];

        // rounding safety
        if (rawRemove > depositors[poolToken][user].raw) {
            rawRemove = depositors[poolToken][user].raw;
        }

        depositors[poolToken][user].raw -= rawRemove;
        totalRaw[poolToken] -= rawRemove;

        totalDeposits[poolToken] -= amount;

        IERC20(poolToken).safeTransfer(user, amount);

        emit Withdraw(poolToken, user, amount, rawRemove);
    }

    function claimCollateral(address poolToken) external nonReentrant {
        require(poolExists[poolToken], "pool not registered");
        address user = msg.sender;
        _updateUserGains(poolToken, user);

        uint256 toClaim = depositors[poolToken][user].pendingCollateral;
        require(toClaim > 0, "no collateral");

        depositors[poolToken][user].pendingCollateral = 0;

        IERC20(collateralOf[poolToken]).safeTransfer(user, toClaim);

        emit CollateralClaimed(poolToken, user, toClaim);
    }

    function _updateUserGains(address poolToken, address user) internal {
        Depositor storage d = depositors[poolToken][user];

        if (d.raw == 0) {
            d.collateralSnapshot = C[poolToken];
            return;
        }

        uint256 deltaC = C[poolToken] - d.collateralSnapshot;
        if (deltaC > 0) {
            uint256 gain = (d.raw * deltaC) / RAY;
            d.pendingCollateral += gain;
        }
        d.collateralSnapshot = C[poolToken];
    }

    // --- Protocol / Liquidation ---

    // protocol covers debt in poolToken units; collateralAmount is collateralToken units
    function offsetDebt(address poolToken, uint256 debtToCover, uint256 collateralAmount) external nonReentrant onlyProtocol {
        require(poolExists[poolToken], "pool not registered");
        require(debtToCover > 0, "debt>0");

        uint256 totalEffective = rawToEffective(poolToken, totalRaw[poolToken]);
        require(totalEffective > 0, "empty pool");

        uint256 debtCovered = debtToCover;
        if (debtCovered >= totalEffective) {
            debtCovered = totalEffective;
        }

        // 1) Distribute collateral proportionally to raw units using totalRaw
        if (collateralAmount > 0) {
            require(totalRaw[poolToken] > 0, "no raw supply");
            IERC20(collateralOf[poolToken]).safeTransferFrom(msg.sender, address(this), collateralAmount);

            uint256 deltaC = (collateralAmount * RAY) / totalRaw[poolToken];
            C[poolToken] += deltaC;
        }

        // 2) Reduce effective balances via multiplicative factor
        if (debtCovered == totalEffective) {
            // drain entire pool
            P[poolToken] = 0;
            totalDeposits[poolToken] = 0;
            // transfer actual token balance of pool to protocol (defensive)
            uint256 bal = IERC20(poolToken).balanceOf(address(this));
            if (bal > 0) {
                IERC20(poolToken).safeTransfer(protocol, bal);
            }
        } else {
            uint256 numerator = (totalEffective - debtCovered) * RAY;
            uint256 denominator = totalEffective;
            uint256 factor = numerator / denominator; // scaled by RAY

            P[poolToken] = (P[poolToken] * factor) / RAY;

            totalDeposits[poolToken] = (totalDeposits[poolToken] * factor) / RAY;

            // transfer the exact tokens corresponding to debtCovered
            IERC20(poolToken).safeTransfer(protocol, debtCovered);
        }

        emit OffsetExecuted(poolToken, msg.sender, debtCovered, collateralAmount);
    }

    // Admin: recover accidentally sent ERC20s (owner)
    function recoverERC20(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "zero to");
        IERC20(token).safeTransfer(to, amount);
    }
}
