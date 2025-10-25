// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StabilityPool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract StabilityPoolTest is Test {
    MockERC20 stable;
    MockERC20 collateral;
    StabilityPool pool;

    address protocol = address(0xBEEF);
    address alice = address(0xA11CE);
    address bob   = address(0xB0B);
    address carol = address(0xCAFE);

    function setUp() public {
        stable = new MockERC20("Stable", "STB");
        collateral = new MockERC20("Collateral", "COL");
        pool = new StabilityPool(address(stable), address(collateral), protocol);

        // Mint stablecoins to users
        stable.mint(alice, 1000 ether);
        stable.mint(bob, 1000 ether);
        stable.mint(carol, 1000 ether);

        // Approve pool for spending
        vm.startPrank(alice);
        stable.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        stable.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(carol);
        stable.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Deposits                                  */
    /* -------------------------------------------------------------------------- */

    function testDepositIncreasesBalanceAndTotal() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        vm.stopPrank();

        // totalDeposits updated
        assertEq(pool.totalDeposits(), 100 ether);

        // effective balance of Alice = 100 ether
        assertEq(pool.effectiveBalanceOf(alice), 100 ether);

        // depositor raw should be > 0 (scaled)
        (uint256 raw,,) = pool.depositors(alice);
        assertGt(raw, 0);
    }

    function testMultipleDepositsMaintainProportions() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        pool.deposit(300 ether);
        vm.stopPrank();

        assertEq(pool.totalDeposits(), 400 ether);
        assertEq(pool.effectiveBalanceOf(alice), 100 ether);
        assertEq(pool.effectiveBalanceOf(bob), 300 ether);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Withdraws                                 */
    /* -------------------------------------------------------------------------- */

    function testWithdrawReducesBalanceAndTotal() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.withdraw(40 ether);
        vm.stopPrank();

        assertEq(pool.totalDeposits(), 60 ether);
        assertApproxEqAbs(pool.effectiveBalanceOf(alice), 60 ether, 1);
    }

    function testCannotWithdrawMoreThanBalance() public {
        vm.startPrank(alice);
        pool.deposit(50 ether);
        vm.expectRevert();
        pool.withdraw(100 ether);
        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*                               Offset (Protocol)                             */
    /* -------------------------------------------------------------------------- */

    function testOnlyProtocolCanOffsetDebt() public {
        vm.startPrank(alice);
        vm.expectRevert(); // not protocol
        pool.offsetDebt(100 ether, 50 ether);
        vm.stopPrank();
    }

    function testOffsetReducesDepositsProportionally() public {
        // Alice: 100, Bob: 300 → total 400
        vm.startPrank(alice);
        pool.deposit(100 ether);
        vm.stopPrank();
        vm.startPrank(bob);
        pool.deposit(300 ether);
        vm.stopPrank();

        // Mint collateral to protocol and offset
        vm.startPrank(protocol);
        collateral.mint(protocol, 200 ether);
        collateral.approve(address(pool), type(uint256).max);
        pool.offsetDebt(200 ether, 200 ether);
        vm.stopPrank();

        // Total deposits reduced by 50%
        assertApproxEqAbs(pool.totalDeposits(), 200 ether, 1);
        assertApproxEqAbs(pool.effectiveBalanceOf(alice), 50 ether, 1);
        assertApproxEqAbs(pool.effectiveBalanceOf(bob), 150 ether, 1);
    }

    function testOffsetAccruesCollateral() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        vm.stopPrank();

        vm.startPrank(protocol);
        collateral.mint(protocol, 50 ether);
        collateral.approve(address(pool), type(uint256).max);
        pool.offsetDebt(50 ether, 50 ether);
        vm.stopPrank();

        // Alice hasn't claimed yet
        assertEq(collateral.balanceOf(alice), 0);

        // Claim
        vm.startPrank(alice);
        pool.claimCollateral();
        vm.stopPrank();

        // Should receive proportional collateral (entire pool was Alice)
        assertApproxEqAbs(collateral.balanceOf(alice), 50 ether, 1);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Collateral Claim                              */
    /* -------------------------------------------------------------------------- */

    function testClaimCollateralMultipleOffsets() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        vm.stopPrank();

        vm.startPrank(protocol);
        collateral.mint(protocol, 100 ether);
        collateral.approve(address(pool), type(uint256).max);
        pool.offsetDebt(50 ether, 100 ether);

        collateral.mint(protocol, 60 ether);
        pool.offsetDebt(30 ether, 60 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        pool.claimCollateral();
        vm.stopPrank();

        assertApproxEqAbs(collateral.balanceOf(alice), 160 ether, 1);
    }

    function testClaimCollateralAfterWithdraw() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        vm.stopPrank();

        vm.startPrank(protocol);
        collateral.mint(protocol, 100 ether);
        collateral.approve(address(pool), type(uint256).max);
        pool.offsetDebt(50 ether, 100 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        pool.withdraw(50 ether); // Should not affect claim entitlement
        pool.claimCollateral();
        vm.stopPrank();

        assertApproxEqAbs(collateral.balanceOf(alice), 100 ether, 1);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Edge Cases                                  */
    /* -------------------------------------------------------------------------- */

    function testCannotDepositZero() public {
        vm.startPrank(alice);
        vm.expectRevert();
        pool.deposit(0);
        vm.stopPrank();
    }

    function testCannotOffsetZeroDebt() public {
        vm.startPrank(protocol);
        vm.expectRevert();
        pool.offsetDebt(0, 10 ether);
        vm.stopPrank();
    }

    function testPAndTotalDepositsResetWhenFullyDrained() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        vm.stopPrank();

        vm.startPrank(protocol);
        collateral.mint(protocol, 10 ether);
        collateral.approve(address(pool), type(uint256).max);
        pool.offsetDebt(100 ether, 10 ether); // Full drain
        vm.stopPrank();

        assertEq(pool.totalDeposits(), 0);
        assertEq(pool.P(), 0);
    }
}
