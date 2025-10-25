// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/*
  BridgeVault

  Purpose:
  - Hold user funds (ERC20 or native ETH) on EVM.
  - Emit Deposit events that relayers consume to mint wrapped tokens on Flow.
  - Allow authorized relayers to release funds back to users after valid burn proofs on Flow.

  Security notes:
  - The contract trusts relayers (they are authorized by owner). Use a multi-sig or DAO-controlled relayer set in production.
  - Off-chain relayer must perform strict verification of burn proofs before calling withdraw().
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BridgeVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Sequential deposit id (global across tokens)
    uint256 public depositIdCounter;

    // authorized relayers who can call withdraw
    mapping(address => bool) public relayers;

    // Optional: track deposited token totals (for monitoring)
    mapping(address => uint256) public totalDeposited; // token address => amount
    uint256 public totalNativeDeposited; // wei

    event RelayerSet(address indexed relayer, bool allowed);
    /// depositId, token (0x0 for native), from, amount, targetChainId (e.g., Flow chain id), targetAddress (bytes on Flow), timestamp
    event Deposited(
        uint256 indexed depositId,
        address indexed token,
        address indexed from,
        uint256 amount,
        uint256 targetChainId,
        bytes targetAddress,
        uint256 timestamp
    );
    /// depositId, token (0x0 for native), to, amount, caller (relayer), timestamp
    event Withdrawn(
        uint256 indexed depositId,
        address indexed token,
        address indexed to,
        uint256 amount,
        address caller,
        uint256 timestamp
    );

    modifier onlyRelayer() {
        require(relayers[msg.sender], "BridgeVault: not relayer");
        _;
    }

    constructor() {
        depositIdCounter = 1; // start at 1 for clarity
    }

    /// Owner controls which addresses are relayers (recommend a multisig in prod)
    function setRelayer(address relayer, bool allowed) external onlyOwner {
        relayers[relayer] = allowed;
        emit RelayerSet(relayer, allowed);
    }

    // -----------------
    // DEPOSITS
    // -----------------

    /// @notice Deposit ERC20 token to be bridged. `targetAddress` is the recipient on Flow (opaque bytes)
    /// @param token ERC20 token address (use 0x0 for native? For ERC20 only; native has separate function)
    /// @param amount token amount (ERC20 decimals respected)
    /// @param targetChainId target chain id (for relayer routing) — use your Flow chain id
    /// @param targetAddress encoded target address on Flow (e.g., user Flow address bytes)
    function depositERC20(
        address token,
        uint256 amount,
        uint256 targetChainId,
        bytes calldata targetAddress
    ) external nonReentrant {
        require(token != address(0), "BridgeVault: token==0");
        require(amount > 0, "BridgeVault: amount==0");

        // transfer token in
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // update accounting
        totalDeposited[token] += amount;

        uint256 id = depositIdCounter++;
        emit Deposited(id, token, msg.sender, amount, targetChainId, targetAddress, block.timestamp);
    }

    /// @notice Deposit native ETH to be bridged (wrap targetAddress similarly)
    /// @param targetChainId target chain id (Flow)
    /// @param targetAddress encoded target address on Flow
    function depositNative(uint256 targetChainId, bytes calldata targetAddress) external payable nonReentrant {
        require(msg.value > 0, "BridgeVault: value==0");

        totalNativeDeposited += msg.value;

        uint256 id = depositIdCounter++;
        emit Deposited(id, address(0), msg.sender, msg.value, targetChainId, targetAddress, block.timestamp);
    }

    // -----------------
    // WITHDRAW (called by relayer after burn proof)
    // -----------------

    /// @notice Relayer releases ERC20 tokens to recipient after verifying burn on Flow
    /// @param depositId id for tracking — useful for relayer off-chain logs
    /// @param token ERC20 token address
    /// @param to destination address on EVM
    /// @param amount amount to send
    function withdrawERC20(
        uint256 depositId,
        address token,
        address to,
        uint256 amount
    ) external onlyRelayer nonReentrant {
        require(token != address(0), "BridgeVault: token==0");
        require(to != address(0), "BridgeVault: to==0");
        require(amount > 0, "BridgeVault: amount==0");

        // transfer out
        IERC20(token).safeTransfer(to, amount);

        // update accounting (best-effort; doesn't underflow protections for malicious calls)
        if (totalDeposited[token] >= amount) {
            totalDeposited[token] -= amount;
        } else {
            totalDeposited[token] = 0;
        }

        emit Withdrawn(depositId, token, to, amount, msg.sender, block.timestamp);
    }

    /// @notice Relayer releases native ETH to recipient after verifying burn on Flow
    function withdrawNative(
        uint256 depositId,
        address payable to,
        uint256 amount
    ) external onlyRelayer nonReentrant {
        require(to != address(0), "BridgeVault: to==0");
        require(amount > 0, "BridgeVault: amount==0");

        // transfer
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "BridgeVault: native transfer failed");

        if (totalNativeDeposited >= amount) {
            totalNativeDeposited -= amount;
        } else {
            totalNativeDeposited = 0;
        }

        emit Withdrawn(depositId, address(0), to, amount, msg.sender, block.timestamp);
    }

    // -----------------
    // ADMIN / RECOVERY
    // -----------------

    /// Owner can recover tokens accidentally sent (not part of normal flow)
    function recoverERC20(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "BridgeVault: to==0");
        IERC20(token).safeTransfer(to, amount);
    }

    /// Owner can recover native ETH accidentally sent
    function recoverNative(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "BridgeVault: to==0");
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "BridgeVault: recover native failed");
    }

    // Allow contract to receive ETH via fallback (if needed)
    receive() external payable {
        totalNativeDeposited += msg.value;
        // not emitting Deposited for plain send — caller should use depositNative for bridge deposits
    }
}
