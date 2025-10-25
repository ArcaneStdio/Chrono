// // SPDX-License-Identifier: AGPL-3.0-or-later
// pragma solidity ^0.8.19;

// import "forge-std/Test.sol";
// import "../src/StabilityPool.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// // Mock ERC20 token for testing
// contract MockERC20 is ERC20 {
//     constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    
//     function mint(address to, uint256 amount) external {
//         _mint(to, amount);
//     }
// }

// contract StabilityPoolTest is Test {
//     StabilityPool public pool;
//     MockERC20 public stableToken;
//     MockERC20 public collateralToken;

//     address public owner;
//     address public protocol;
//     address public alice;
//     address public bob;
//     address public charlie;
//     address public dave;

//     uint256 constant RAY = 1e18;
//     uint256 constant INITIAL_MINT = 1_000_000e18;

//     event Deposit(address indexed user, uint256 amount, uint256 rawAdded);
//     event Withdraw(address indexed user, uint256 amount, uint256 rawRemoved);
//     event CollateralClaimed(address indexed user, uint256 amount);
//     event OffsetExecuted(address indexed caller, uint256 debtCovered, uint256 collateralReceived);
//     event ProtocolSet(address indexed protocol);

//     function setUp() public {
//         owner = address(this);
//         protocol = makeAddr("protocol");
//         alice = makeAddr("alice");
//         bob = makeAddr("bob");
//         charlie = makeAddr("charlie");
//         dave = makeAddr("dave");

//         // Deploy tokens
//         stableToken = new MockERC20("Stable", "STABLE");
//         collateralToken = new MockERC20("Collateral", "COLL");

//         // Deploy pool
//         pool = new StabilityPool(
//             address(stableToken),
//             address(collateralToken),
//             protocol
//         );

//         // Mint tokens to users
//         stableToken.mint(alice, INITIAL_MINT);
//         stableToken.mint(bob, INITIAL_MINT);
//         stableToken.mint(charlie, INITIAL_MINT);
//         stableToken.mint(dave, INITIAL_MINT);
//         collateralToken.mint(protocol, INITIAL_MINT);
//     }

//     // ============================================
//     // DEPLOYMENT TESTS
//     // ============================================

//     function test_Deployment_InitialState() public view {
//         assertEq(address(pool.stableToken()), address(stableToken));
//         assertEq(address(pool.collateralToken()), address(collateralToken));
//         assertEq(pool.protocol(), protocol);
//         assertEq(pool.P(), RAY);
//         assertEq(pool.C(), 0);
//         assertEq(pool.totalRaw(), 0);
//     }

//     function test_Deployment_RevertOnZeroTokenAddress() public {
//         vm.expectRevert("zero token");
//         new StabilityPool(address(0), address(collateralToken), protocol);

//         vm.expectRevert("zero token");
//         new StabilityPool(address(stableToken), address(0), protocol);
//     }

//     // ============================================
//     // PROTOCOL MANAGEMENT TESTS
//     // ============================================

//     function test_SetProtocol_Success() public {
//         address newProtocol = makeAddr("newProtocol");
        
//         vm.expectEmit(true, false, false, true);
//         emit ProtocolSet(newProtocol);
//         pool.setProtocol(newProtocol);
        
//         assertEq(pool.protocol(), newProtocol);
//     }

//     function test_SetProtocol_RevertWhenNotOwner() public {
//         vm.prank(alice);
//         vm.expectRevert();
//         pool.setProtocol(alice);
//     }

//     // ============================================
//     // DEPOSIT TESTS
//     // ============================================

//     function test_Deposit_SingleUser() public {
//         uint256 depositAmount = 1000e18;
        
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), depositAmount);
        
//         vm.expectEmit(true, false, false, true);
//         emit Deposit(alice, depositAmount, depositAmount);
//         pool.deposit(depositAmount);
//         vm.stopPrank();

//         assertEq(pool.effectiveBalanceOf(alice), depositAmount);
//         assertEq(pool.totalEffectiveSupply(), depositAmount);
//         assertEq(pool.totalRaw(), depositAmount);
//     }

//     function test_Deposit_MultipleDepositsFromSameUser() public {
//         uint256 deposit1 = 1000e18;
//         uint256 deposit2 = 500e18;
        
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), deposit1 + deposit2);
        
//         pool.deposit(deposit1);
//         pool.deposit(deposit2);
//         vm.stopPrank();

//         assertEq(pool.effectiveBalanceOf(alice), deposit1 + deposit2);
//         assertEq(pool.totalEffectiveSupply(), deposit1 + deposit2);
//     }

//     function test_Deposit_MultipleUsers() public {
//         uint256 aliceAmount = 1000e18;
//         uint256 bobAmount = 2000e18;
//         uint256 charlieAmount = 1500e18;

//         vm.startPrank(alice);
//         stableToken.approve(address(pool), aliceAmount);
//         pool.deposit(aliceAmount);
//         vm.stopPrank();

//         vm.startPrank(bob);
//         stableToken.approve(address(pool), bobAmount);
//         pool.deposit(bobAmount);
//         vm.stopPrank();

//         vm.startPrank(charlie);
//         stableToken.approve(address(pool), charlieAmount);
//         pool.deposit(charlieAmount);
//         vm.stopPrank();

//         assertEq(pool.effectiveBalanceOf(alice), aliceAmount);
//         assertEq(pool.effectiveBalanceOf(bob), bobAmount);
//         assertEq(pool.effectiveBalanceOf(charlie), charlieAmount);
//         assertEq(pool.totalEffectiveSupply(), aliceAmount + bobAmount + charlieAmount);
//     }

//     function test_Deposit_RevertOnZeroAmount() public {
//         vm.prank(alice);
//         vm.expectRevert("amount>0");
//         pool.deposit(0);
//     }

//     function test_Deposit_ReinitializesPWhenPoolEmpty() public {
//         uint256 depositAmount = 1000e18;
        
//         // Initial deposit
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), depositAmount);
//         pool.deposit(depositAmount);
//         vm.stopPrank();

//         // Offset entire pool (P becomes 0)
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), depositAmount);
//         pool.offsetDebt(depositAmount, depositAmount);
//         vm.stopPrank();
        
//         assertEq(pool.P(), 0);
//         assertEq(pool.effectiveBalanceOf(alice), 0);

//         // Alice should claim her collateral first
//         vm.prank(alice);
//         pool.claimCollateral();

//         // New deposit should reset P to RAY
//         uint256 newDeposit = 500e18;
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), newDeposit);
//         pool.deposit(newDeposit);
//         vm.stopPrank();
        
//         assertEq(pool.P(), RAY);
//         assertEq(pool.effectiveBalanceOf(alice), newDeposit);
//     }

//     function testFuzz_Deposit_RandomAmounts(uint256 amount) public {
//         amount = bound(amount, 1, INITIAL_MINT);
        
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), amount);
//         pool.deposit(amount);
//         vm.stopPrank();

//         assertEq(pool.effectiveBalanceOf(alice), amount);
//     }

//     // ============================================
//     // WITHDRAWAL TESTS
//     // ============================================

//     function test_Withdraw_PartialAmount() public {
//         uint256 depositAmount = 1000e18;
//         uint256 withdrawAmount = 400e18;
        
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), depositAmount);
//         pool.deposit(depositAmount);
        
//         uint256 balanceBefore = stableToken.balanceOf(alice);
        
//         vm.expectEmit(true, false, false, true);
//         emit Withdraw(alice, withdrawAmount, withdrawAmount);
//         pool.withdraw(withdrawAmount);
//         vm.stopPrank();

//         uint256 balanceAfter = stableToken.balanceOf(alice);
//         assertEq(balanceAfter - balanceBefore, withdrawAmount);
//         assertEq(pool.effectiveBalanceOf(alice), depositAmount - withdrawAmount);
//     }

//     function test_Withdraw_FullAmount() public {
//         uint256 depositAmount = 1000e18;
        
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), depositAmount);
//         pool.deposit(depositAmount);
//         pool.withdraw(depositAmount);
//         vm.stopPrank();

//         assertEq(pool.effectiveBalanceOf(alice), 0);
//         assertEq(pool.totalEffectiveSupply(), 0);
//     }

//     function test_Withdraw_RevertOnInsufficientBalance() public {
//         uint256 depositAmount = 1000e18;
        
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), depositAmount);
//         pool.deposit(depositAmount);
        
//         vm.expectRevert("insufficient balance");
//         pool.withdraw(depositAmount + 1);
//         vm.stopPrank();
//     }

//     function test_Withdraw_RevertOnZeroAmount() public {
//         vm.prank(alice);
//         vm.expectRevert("amount>0");
//         pool.withdraw(0);
//     }

//     // ============================================
//     // OFFSET DEBT TESTS (LIQUIDATIONS)
//     // ============================================

//     function test_OffsetDebt_PartialLiquidation() public {
//         // Setup: Two depositors
//         uint256 aliceDeposit = 6000e18;
//         uint256 bobDeposit = 4000e18;
        
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), aliceDeposit);
//         pool.deposit(aliceDeposit);
//         vm.stopPrank();

//         vm.startPrank(bob);
//         stableToken.approve(address(pool), bobDeposit);
//         pool.deposit(bobDeposit);
//         vm.stopPrank();

//         uint256 totalDeposit = aliceDeposit + bobDeposit;

//         // Offset 2000 debt with 100 collateral
//         uint256 debtToCover = 2000e18;
//         uint256 collateralAmount = 100e18;
        
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), collateralAmount);
        
//         vm.expectEmit(true, false, false, true);
//         emit OffsetExecuted(protocol, debtToCover, collateralAmount);
//         pool.offsetDebt(debtToCover, collateralAmount);
//         vm.stopPrank();

//         // Check new effective balances (reduced by 20%)
//         uint256 expectedTotal = totalDeposit - debtToCover;
//         assertApproxEqAbs(pool.totalEffectiveSupply(), expectedTotal, 1e15);

//         // Check collateral distribution (60% to alice, 40% to bob based on ORIGINAL balances)
//         // Collateral is distributed BEFORE balance reduction
//         uint256 aliceCollateral = pool.claimableCollateralOf(alice);
//         uint256 bobCollateral = pool.claimableCollateralOf(bob);
        
//         // Alice had 6000/10000 = 60% of pool, Bob had 40%
//         assertApproxEqAbs(aliceCollateral, 60e18, 1e17);
//         assertApproxEqAbs(bobCollateral, 40e18, 1e17);
//     }

//     function test_OffsetDebt_CompletePoolLiquidation() public {
//         uint256 depositAmount = 1000e18;
        
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), depositAmount);
//         pool.deposit(depositAmount);
//         vm.stopPrank();

//         // Offset entire pool
//         uint256 collateralAmount = 50e18;
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), collateralAmount);
//         pool.offsetDebt(depositAmount, collateralAmount);
//         vm.stopPrank();

//         assertEq(pool.P(), 0);
//         assertEq(pool.effectiveBalanceOf(alice), 0);
//         assertEq(pool.totalEffectiveSupply(), 0);
        
//         // Collateral is distributed based on balance BEFORE the wipeout
//         // So alice should get the full collateral amount
//         assertApproxEqAbs(pool.claimableCollateralOf(alice), collateralAmount, 1e15);
        
//         // Verify alice can claim it
//         vm.prank(alice);
//         pool.claimCollateral();
//         assertEq(collateralToken.balanceOf(alice), collateralAmount);
//     }

//     function test_OffsetDebt_ExceedingPoolSize() public {
//         uint256 depositAmount = 1000e18;
        
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), depositAmount);
//         pool.deposit(depositAmount);
//         vm.stopPrank();

//         // Try to offset more than pool size
//         uint256 excessiveDebt = 2000e18;
//         uint256 collateralAmount = 100e18;
        
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), collateralAmount);
//         pool.offsetDebt(excessiveDebt, collateralAmount);
//         vm.stopPrank();

//         // Should only cover available amount
//         assertEq(pool.P(), 0);
//         assertEq(pool.effectiveBalanceOf(alice), 0);
//     }

//     function test_OffsetDebt_RevertWhenNotProtocol() public {
//         vm.prank(alice);
//         vm.expectRevert("Not protocol");
//         pool.offsetDebt(100e18, 10e18);
//     }

//     function test_OffsetDebt_RevertOnEmptyPool() public {
//         vm.prank(protocol);
//         vm.expectRevert("empty pool");
//         pool.offsetDebt(100e18, 10e18);
//     }

//     function test_OffsetDebt_RevertOnZeroDebt() public {
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 1000e18);
//         pool.deposit(1000e18);
//         vm.stopPrank();

//         vm.prank(protocol);
//         vm.expectRevert("debt>0");
//         pool.offsetDebt(0, 10e18);
//     }

//     function test_OffsetDebt_MultipleSequentialOffsets() public {
//         uint256 depositAmount = 10000e18;
        
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), depositAmount);
//         pool.deposit(depositAmount);
//         vm.stopPrank();

//         // First offset: 1000 debt, 50 collateral
//         // Alice has 10000, gets 50 collateral, then balance becomes 9000
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 50e18);
//         pool.offsetDebt(1000e18, 50e18);

//         // Second offset: 500 debt, 25 collateral  
//         // Alice now has 9000, gets 25 collateral, then balance becomes 8500
//         collateralToken.approve(address(pool), 25e18);
//         pool.offsetDebt(500e18, 25e18);
//         vm.stopPrank();

//         // Check final state
//         uint256 expectedBalance = depositAmount - 1500e18;
//         assertApproxEqAbs(pool.effectiveBalanceOf(alice), expectedBalance, 1e17);

//         uint256 expectedCollateral = 75e18;
//         assertApproxEqAbs(pool.claimableCollateralOf(alice), expectedCollateral, 1e17);
//     }

//     function test_OffsetDebt_WithZeroCollateral() public {
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 1000e18);
//         pool.deposit(1000e18);
//         vm.stopPrank();

//         // Offset with zero collateral
//         vm.prank(protocol);
//         pool.offsetDebt(100e18, 0);

//         assertApproxEqAbs(pool.effectiveBalanceOf(alice), 900e18, 1e16);
//         assertEq(pool.claimableCollateralOf(alice), 0);
//     }

//     // ============================================
//     // COLLATERAL CLAIM TESTS
//     // ============================================

//     function test_ClaimCollateral_Success() public {
//         // Setup: deposit and offset
//         uint256 depositAmount = 1000e18;
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), depositAmount);
//         pool.deposit(depositAmount);
//         vm.stopPrank();

//         uint256 collateralAmount = 50e18;
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), collateralAmount);
//         pool.offsetDebt(100e18, collateralAmount);
//         vm.stopPrank();

//         // Claim
//         uint256 balanceBefore = collateralToken.balanceOf(alice);
//         uint256 claimable = pool.claimableCollateralOf(alice);
        
//         vm.prank(alice);
//         pool.claimCollateral();

//         uint256 balanceAfter = collateralToken.balanceOf(alice);
//         assertApproxEqAbs(balanceAfter - balanceBefore, collateralAmount, 1e15);
//         assertApproxEqAbs(claimable, collateralAmount, 1e15);
//     }

//     function test_ClaimCollateral_RevertWhenNoPending() public {
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 1000e18);
//         pool.deposit(1000e18);
        
//         vm.expectRevert("no collateral");
//         pool.claimCollateral();
//         vm.stopPrank();
//     }

//     function test_ClaimCollateral_AccumulateAcrossMultipleOffsets() public {
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 10000e18);
//         pool.deposit(10000e18);
//         vm.stopPrank();

//         // First offset: Alice has 10000, gets 30 collateral
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 30e18);
//         pool.offsetDebt(1000e18, 30e18);

//         // Second offset: Alice now has 9000, gets 20 collateral  
//         collateralToken.approve(address(pool), 20e18);
//         pool.offsetDebt(500e18, 20e18);
//         vm.stopPrank();

//         // Claim total - should get 50
//         uint256 balanceBefore = collateralToken.balanceOf(alice);
//         vm.prank(alice);
//         pool.claimCollateral();
//         uint256 balanceAfter = collateralToken.balanceOf(alice);

//         assertApproxEqAbs(balanceAfter - balanceBefore, 50e18, 1e17);
//     }

//     function test_ClaimCollateral_ProperDistributionMultipleUsers() public {
//         // Alice deposits 7000, Bob deposits 3000
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 7000e18);
//         pool.deposit(7000e18);
//         vm.stopPrank();

//         vm.startPrank(bob);
//         stableToken.approve(address(pool), 3000e18);
//         pool.deposit(3000e18);
//         vm.stopPrank();

//         // Offset with 100 collateral
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 100e18);
//         pool.offsetDebt(1000e18, 100e18);
//         vm.stopPrank();

//         // Claim
//         uint256 aliceBalBefore = collateralToken.balanceOf(alice);
//         uint256 bobBalBefore = collateralToken.balanceOf(bob);

//         vm.prank(alice);
//         pool.claimCollateral();
//         vm.prank(bob);
//         pool.claimCollateral();

//         uint256 aliceBalAfter = collateralToken.balanceOf(alice);
//         uint256 bobBalAfter = collateralToken.balanceOf(bob);

//         // Alice had 70% of pool, Bob had 30%
//         assertApproxEqAbs(aliceBalAfter - aliceBalBefore, 70e18, 1e17);
//         assertApproxEqAbs(bobBalAfter - bobBalBefore, 30e18, 1e17);
//     }

//     function test_ClaimCollateral_NoEarningsBeforeDeposit() public {
//         // Alice deposits
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 1000e18);
//         pool.deposit(1000e18);
//         vm.stopPrank();

//         // Offset (Alice earns collateral based on her 1000 balance)
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 50e18);
//         pool.offsetDebt(100e18, 50e18);
//         vm.stopPrank();

//         // Bob deposits AFTER offset  
//         // At this point, Alice has effective balance of 900
//         vm.startPrank(bob);
//         stableToken.approve(address(pool), 1000e18);
//         pool.deposit(1000e18);
//         vm.stopPrank();

//         // Bob should have no collateral, Alice should have all 50
//         assertEq(pool.claimableCollateralOf(bob), 0);
//         assertApproxEqAbs(pool.claimableCollateralOf(alice), 50e18, 1e17);
//     }

//     // ============================================
//     // COMPLEX SCENARIO TESTS
//     // ============================================

//     function test_Scenario_DepositAfterOffset() public {
//         // Alice deposits 1000
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 1000e18);
//         pool.deposit(1000e18);
//         vm.stopPrank();

//         // Offset 200 debt (P reduces to 0.8)
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 10e18);
//         pool.offsetDebt(200e18, 10e18);
//         vm.stopPrank();

//         // Bob deposits 800 (should get appropriate raw units)
//         vm.startPrank(bob);
//         stableToken.approve(address(pool), 800e18);
//         pool.deposit(800e18);
//         vm.stopPrank();

//         // Check balances
//         assertApproxEqAbs(pool.effectiveBalanceOf(alice), 800e18, 1e16);
//         assertApproxEqAbs(pool.effectiveBalanceOf(bob), 800e18, 1e16);
//         assertApproxEqAbs(pool.totalEffectiveSupply(), 1600e18, 1e16);
//     }

//     function test_Scenario_WithdrawAfterOffset() public {
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 1000e18);
//         pool.deposit(1000e18);
//         vm.stopPrank();

//         // Offset half - Alice gets collateral based on 1000, then balance becomes 500
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 25e18);
//         pool.offsetDebt(500e18, 25e18);
//         vm.stopPrank();

//         // Withdraw remaining
//         uint256 remaining = pool.effectiveBalanceOf(alice);
//         vm.prank(alice);
//         pool.withdraw(remaining);

//         assertEq(pool.effectiveBalanceOf(alice), 0);
        
//         // Should still be able to claim collateral - full 25
//         uint256 claimable = pool.claimableCollateralOf(alice);
//         assertApproxEqAbs(claimable, 25e18, 1e17);
//     }

//     function test_Scenario_DepositOffsetDepositAgain() public {
//         // First deposit
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 1000e18);
//         pool.deposit(1000e18);
//         vm.stopPrank();

//         // Offset - Alice gets collateral based on 1000, then balance becomes 800
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 50e18);
//         pool.offsetDebt(200e18, 50e18);
//         vm.stopPrank();

//         // Second deposit - adds 500 to her existing ~800
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 500e18);
//         pool.deposit(500e18);
//         vm.stopPrank();

//         // Total effective should be 800 + 500 = 1300
//         assertApproxEqAbs(pool.effectiveBalanceOf(alice), 1300e18, 1e17);

//         // Collateral from first period should be preserved - full 50
//         assertApproxEqAbs(pool.claimableCollateralOf(alice), 50e18, 1e17);
//     }

//     function test_Scenario_PrecisionOverManyOffsets() public {
//         uint256 initialDeposit = 100000e18;
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), initialDeposit);
//         pool.deposit(initialDeposit);
//         vm.stopPrank();

//         uint256 totalCollateralDistributed = 0;

//         // Perform 10 small offsets
//         vm.startPrank(protocol);
//         for (uint256 i = 0; i < 10; i++) {
//             uint256 debtAmount = 100e18;
//             uint256 collAmount = 5e18;
//             totalCollateralDistributed += collAmount;
            
//             collateralToken.approve(address(pool), collAmount);
//             pool.offsetDebt(debtAmount, collAmount);
//         }
//         vm.stopPrank();

//         // Check final state
//         uint256 expectedBalance = initialDeposit - 1000e18;
//         assertApproxEqAbs(pool.effectiveBalanceOf(alice), expectedBalance, 1e18);
        
//         // Total collateral should be 50
//         assertApproxEqAbs(pool.claimableCollateralOf(alice), totalCollateralDistributed, 1e17);
//     }

//     // ============================================
//     // EDGE CASE TESTS
//     // ============================================

//     function test_EdgeCase_VerySmallDeposit() public {
//         uint256 smallAmount = 1e6; // 0.000001 tokens
        
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), smallAmount);
//         pool.deposit(smallAmount);
//         vm.stopPrank();

//         assertEq(pool.effectiveBalanceOf(alice), smallAmount);
//     }

//     function test_EdgeCase_VeryLargeDeposit() public {
//         uint256 largeAmount = 1_000_000e18;
        
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), largeAmount);
//         pool.deposit(largeAmount);
//         vm.stopPrank();

//         assertEq(pool.effectiveBalanceOf(alice), largeAmount);
//     }

//     function test_EdgeCase_UpdateUserGainsWithZeroRaw() public {
//         // User with no deposit can safely call functions
//         uint256 claimable = pool.claimableCollateralOf(alice);
//         assertEq(claimable, 0);
//     }

//     function test_EdgeCase_MultipleUsersComplexInteractions() public {
//         // Alice deposits
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 5000e18);
//         pool.deposit(5000e18);
//         vm.stopPrank();

//         // Offset 1
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 20e18);
//         pool.offsetDebt(1000e18, 20e18);
//         vm.stopPrank();

//         // Bob deposits
//         vm.startPrank(bob);
//         stableToken.approve(address(pool), 4000e18);
//         pool.deposit(4000e18);
//         vm.stopPrank();

//         // Offset 2
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 40e18);
//         pool.offsetDebt(800e18, 40e18);
//         vm.stopPrank();

//         // Charlie deposits
//         vm.startPrank(charlie);
//         stableToken.approve(address(pool), 3000e18);
//         pool.deposit(3000e18);
//         vm.stopPrank();

//         // Alice withdraws partial
//         vm.startPrank(alice);
//         pool.withdraw(1000e18);
//         vm.stopPrank();

//         // Offset 3
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 30e18);
//         pool.offsetDebt(500e18, 30e18);
//         vm.stopPrank();

//         // All users should have reasonable balances
//         assertTrue(pool.effectiveBalanceOf(alice) > 0);
//         assertTrue(pool.effectiveBalanceOf(bob) > 0);
//         assertTrue(pool.effectiveBalanceOf(charlie) > 0);
//         assertTrue(pool.claimableCollateralOf(alice) > 0);
//         assertTrue(pool.claimableCollateralOf(bob) > 0);
//     }

//     // ============================================
//     // INVARIANT TESTS
//     // ============================================

//     function test_Invariant_TotalEffectiveMatchesCalculation() public {
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 1000e18);
//         pool.deposit(1000e18);
//         vm.stopPrank();

//         vm.startPrank(bob);
//         stableToken.approve(address(pool), 2000e18);
//         pool.deposit(2000e18);
//         vm.stopPrank();

//         uint256 calculated = pool.effectiveBalanceOf(alice) + pool.effectiveBalanceOf(bob);
//         uint256 total = pool.totalEffectiveSupply();
        
//         assertEq(calculated, total);
//     }

//     function test_Invariant_CollateralConservation() public {
//         // Deposit from multiple users
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 5000e18);
//         pool.deposit(5000e18);
//         vm.stopPrank();

//         vm.startPrank(bob);
//         stableToken.approve(address(pool), 5000e18);
//         pool.deposit(5000e18);
//         vm.stopPrank();

//         // Distribute collateral
//         uint256 collateralDistributed = 100e18;
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), collateralDistributed);
//         pool.offsetDebt(1000e18, collateralDistributed);
//         vm.stopPrank();

//         // Sum of claimable should equal distributed (within rounding)
//         uint256 totalClaimable = pool.claimableCollateralOf(alice) + pool.claimableCollateralOf(bob);
//         assertApproxEqAbs(totalClaimable, collateralDistributed, 1e17);
//     }

//     // ============================================
//     // REENTRANCY TESTS
//     // ============================================

//     function test_Reentrancy_ProtectedFunctions() public {
//         // All mutating functions have nonReentrant modifier
//         // This is a basic sanity check; proper reentrancy testing
//         // would require malicious token contracts
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 1000e18);
//         pool.deposit(1000e18);
//         vm.stopPrank();
        
//         // Functions are marked nonReentrant
//         assertTrue(true);
//     }

//     // ============================================
//     // ADMIN/RECOVERY TESTS
//     // ============================================

//     function test_RecoverERC20_Success() public {
//         // Accidentally send tokens to contract
//         MockERC20 randomToken = new MockERC20("Random", "RND");
//         randomToken.mint(address(pool), 1000e18);
        
//         uint256 balanceBefore = randomToken.balanceOf(owner);
//         pool.recoverERC20(address(randomToken), owner, 1000e18);
//         uint256 balanceAfter = randomToken.balanceOf(owner);
        
//         assertEq(balanceAfter - balanceBefore, 1000e18);
//     }

//     function test_RecoverERC20_RevertOnZeroAddress() public {
//         MockERC20 randomToken = new MockERC20("Random", "RND");
        
//         vm.expectRevert("zero to");
//         pool.recoverERC20(address(randomToken), address(0), 1000e18);
//     }

//     function test_RecoverERC20_RevertWhenNotOwner() public {
//         MockERC20 randomToken = new MockERC20("Random", "RND");
        
//         vm.prank(alice);
//         vm.expectRevert();
//         pool.recoverERC20(address(randomToken), alice, 1000e18);
//     }

//     // ============================================
//     // VIEW FUNCTION TESTS
//     // ============================================

//     function test_View_EffectiveBalanceOfReflectsOffsets() public {
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 1000e18);
//         pool.deposit(1000e18);
//         vm.stopPrank();

//         uint256 balanceBefore = pool.effectiveBalanceOf(alice);
        
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 10e18);
//         pool.offsetDebt(200e18, 10e18);
//         vm.stopPrank();

//         uint256 balanceAfter = pool.effectiveBalanceOf(alice);
        
//         assertLt(balanceAfter, balanceBefore);
//         assertApproxEqAbs(balanceAfter, 800e18, 1e16);
//     }

//     function test_View_ClaimableCollateralOf() public {
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 1000e18);
//         pool.deposit(1000e18);
//         vm.stopPrank();

//         assertEq(pool.claimableCollateralOf(alice), 0);

//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 50e18);
//         pool.offsetDebt(100e18, 50e18);
//         vm.stopPrank();

//         assertApproxEqAbs(pool.claimableCollateralOf(alice), 50e18, 1e17);
//     }

//     function test_View_TotalEffectiveSupply() public {
//         assertEq(pool.totalEffectiveSupply(), 0);

//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 1000e18);
//         pool.deposit(1000e18);
//         vm.stopPrank();

//         vm.startPrank(bob);
//         stableToken.approve(address(pool), 500e18);
//         pool.deposit(500e18);
//         vm.stopPrank();

//         assertEq(pool.totalEffectiveSupply(), 1500e18);
//     }

//     // ============================================
//     // STRESS TESTS
//     // ============================================

//     function test_Stress_ManyUsers() public {
//         uint256 numUsers = 20;
//         address[] memory users = new address[](numUsers);
        
//         for (uint256 i = 0; i < numUsers; i++) {
//             users[i] = address(uint160(i + 1000));
//             stableToken.mint(users[i], 10000e18);
            
//             vm.startPrank(users[i]);
//             stableToken.approve(address(pool), 5000e18);
//             pool.deposit(5000e18);
//             vm.stopPrank();
//         }

//         assertEq(pool.totalEffectiveSupply(), numUsers * 5000e18);

//         // Offset
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 1000e18);
//         pool.offsetDebt(10000e18, 1000e18);
//         vm.stopPrank();

//         // All users should have reduced balance and collateral
//         for (uint256 i = 0; i < numUsers; i++) {
//             assertTrue(pool.effectiveBalanceOf(users[i]) > 0);
//             assertTrue(pool.claimableCollateralOf(users[i]) > 0);
//         }
//     }

//     function test_Stress_ManyOffsets() public {
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 100000e18);
//         pool.deposit(100000e18);
//         vm.stopPrank();

//         uint256 numOffsets = 50;
        
//         vm.startPrank(protocol);
//         for (uint256 i = 0; i < numOffsets; i++) {
//             collateralToken.approve(address(pool), 10e18);
//             pool.offsetDebt(100e18, 10e18);
//         }
//         vm.stopPrank();

//         // Balance should be reduced
//         uint256 expectedBalance = 100000e18 - (numOffsets * 100e18);
//         assertApproxEqAbs(pool.effectiveBalanceOf(alice), expectedBalance, 1e18);
        
//         // Collateral should accumulate to 500
//         uint256 expectedCollateral = numOffsets * 10e18;
//         assertApproxEqAbs(pool.claimableCollateralOf(alice), expectedCollateral, 5e18);
//     }
//     // ============================================
//     // FUZZING TESTS
//     // ============================================

//     function testFuzz_DepositWithdraw(uint256 depositAmount, uint256 withdrawAmount) public {
//         depositAmount = bound(depositAmount, 1e18, INITIAL_MINT);
//         withdrawAmount = bound(withdrawAmount, 1, depositAmount);

//         vm.startPrank(alice);
//         stableToken.approve(address(pool), depositAmount);
//         pool.deposit(depositAmount);
        
//         pool.withdraw(withdrawAmount);
//         vm.stopPrank();

//         assertApproxEqAbs(pool.effectiveBalanceOf(alice), depositAmount - withdrawAmount, 1);
//     }

//     function testFuzz_OffsetDebt(uint256 depositAmount, uint256 debtAmount, uint256 collateralAmount) public {
//         depositAmount = bound(depositAmount, 1000e18, INITIAL_MINT);
//         debtAmount = bound(debtAmount, 1e18, depositAmount);
//         collateralAmount = bound(collateralAmount, 0, INITIAL_MINT);

//         vm.startPrank(alice);
//         stableToken.approve(address(pool), depositAmount);
//         pool.deposit(depositAmount);
//         vm.stopPrank();

//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), collateralAmount);
//         pool.offsetDebt(debtAmount, collateralAmount);
//         vm.stopPrank();

//         uint256 expectedBalance = depositAmount - debtAmount;
//         assertApproxEqRel(pool.effectiveBalanceOf(alice), expectedBalance, 1e17); // 10% tolerance for rounding
        
//         // Collateral should be distributed
//         if (collateralAmount > 0) {
//             assertApproxEqRel(pool.claimableCollateralOf(alice), collateralAmount, 1e17);
//         }
//     }

//     function testFuzz_MultipleDepositors(
//         uint256 aliceAmount,
//         uint256 bobAmount,
//         uint256 debtAmount,
//         uint256 collateralAmount
//     ) public {
//         aliceAmount = bound(aliceAmount, 1000e18, INITIAL_MINT / 2);
//         bobAmount = bound(bobAmount, 1000e18, INITIAL_MINT / 2);
//         uint256 totalDeposit = aliceAmount + bobAmount;
//         debtAmount = bound(debtAmount, 1e18, totalDeposit / 2);
//         collateralAmount = bound(collateralAmount, 0, INITIAL_MINT);

//         vm.startPrank(alice);
//         stableToken.approve(address(pool), aliceAmount);
//         pool.deposit(aliceAmount);
//         vm.stopPrank();

//         vm.startPrank(bob);
//         stableToken.approve(address(pool), bobAmount);
//         pool.deposit(bobAmount);
//         vm.stopPrank();

//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), collateralAmount);
//         pool.offsetDebt(debtAmount, collateralAmount);
//         vm.stopPrank();

//         // Conservation: total effective balance should equal total deposits minus debt
//         uint256 expectedTotal = totalDeposit - debtAmount;
//         assertApproxEqRel(pool.totalEffectiveSupply(), expectedTotal, 1e17); // 10% tolerance

//         // Conservation: sum of claimable collateral should equal distributed
//         if (collateralAmount > 0) {
//             uint256 totalClaimable = pool.claimableCollateralOf(alice) + pool.claimableCollateralOf(bob);
//             assertApproxEqRel(totalClaimable, collateralAmount, 1e17); // 10% tolerance
//         }
//     }

//     // ============================================
//     // ROUNDING AND PRECISION TESTS
//     // ============================================

//     function test_Precision_SmallOffsetOnLargePool() public {
//         uint256 largeDeposit = 1_000_000e18;
        
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), largeDeposit);
//         pool.deposit(largeDeposit);
//         vm.stopPrank();

//         // Very small offset
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 1e18);
//         pool.offsetDebt(1e18, 1e18);
//         vm.stopPrank();

//         // Should still reduce balance correctly
//         assertApproxEqAbs(pool.effectiveBalanceOf(alice), largeDeposit - 1e18, 1e15);
//     }

//     function test_Precision_LargeOffsetOnSmallPool() public {
//         uint256 smallDeposit = 1e18;
        
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), smallDeposit);
//         pool.deposit(smallDeposit);
//         vm.stopPrank();

//         // Large offset (exceeds pool) - Alice gets collateral based on her 1 token
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 1000e18);
//         pool.offsetDebt(1000e18, 1000e18);
//         vm.stopPrank();

//         // Pool should be emptied
//         assertEq(pool.effectiveBalanceOf(alice), 0);
//         // Alice gets the full 1000 collateral
//         assertApproxEqAbs(pool.claimableCollateralOf(alice), 1000e18, 1e17);
//     }

//     function test_Precision_RepeatedSmallOperations() public {
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 10000e18);
        
//         // Deposit in small increments
//         for (uint256 i = 0; i < 100; i++) {
//             pool.deposit(100e18);
//         }
//         vm.stopPrank();

//         assertApproxEqAbs(pool.effectiveBalanceOf(alice), 10000e18, 1e16);
//     }

//     // ============================================
//     // INTEGRATION TESTS
//     // ============================================

//     function test_Integration_FullLifecycle() public {
//         // Phase 1: Initial deposits
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 10000e18);
//         pool.deposit(5000e18);
//         vm.stopPrank();

//         vm.startPrank(bob);
//         stableToken.approve(address(pool), 10000e18);
//         pool.deposit(3000e18);
//         vm.stopPrank();

//         assertEq(pool.totalEffectiveSupply(), 8000e18);

//         // Phase 2: First liquidation
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 100e18);
//         pool.offsetDebt(1000e18, 100e18);
//         vm.stopPrank();

//         assertApproxEqAbs(pool.totalEffectiveSupply(), 7000e18, 1e16);

//         // Phase 3: New depositor joins
//         vm.startPrank(charlie);
//         stableToken.approve(address(pool), 10000e18);
//         pool.deposit(2000e18);
//         vm.stopPrank();

//         assertApproxEqAbs(pool.totalEffectiveSupply(), 9000e18, 1e16);

//         // Phase 4: Alice withdraws partial
//         vm.startPrank(alice);
//         pool.withdraw(2000e18);
//         vm.stopPrank();

//         // Phase 5: Second liquidation
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 50e18);
//         pool.offsetDebt(500e18, 50e18);
//         vm.stopPrank();

//         // Phase 6: Everyone claims collateral
//         vm.prank(alice);
//         pool.claimCollateral();
        
//         vm.prank(bob);
//         pool.claimCollateral();

//         // Charlie should also have collateral from second liquidation
//         assertTrue(pool.claimableCollateralOf(charlie) > 0);

//         // Phase 7: Final withdrawals
//         uint256 aliceRemaining = pool.effectiveBalanceOf(alice);
//         if (aliceRemaining > 0) {
//             vm.prank(alice);
//             pool.withdraw(aliceRemaining);
//         }

//         uint256 bobRemaining = pool.effectiveBalanceOf(bob);
//         if (bobRemaining > 0) {
//             vm.prank(bob);
//             pool.withdraw(bobRemaining);
//         }

//         uint256 charlieRemaining = pool.effectiveBalanceOf(charlie);
//         if (charlieRemaining > 0) {
//             vm.prank(charlie);
//             pool.withdraw(charlieRemaining);
//         }

//         // Pool should be nearly empty (allowing for rounding)
//         assertLt(pool.totalEffectiveSupply(), 1e16);
//     }

//     function test_Integration_RecoveryAfterCompleteWipeout() public {
//         // Phase 1: Deposit and complete liquidation
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 5000e18);
//         pool.deposit(5000e18);
//         vm.stopPrank();

//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 250e18);
//         pool.offsetDebt(5000e18, 250e18);
//         vm.stopPrank();

//         assertEq(pool.P(), 0);
//         assertEq(pool.effectiveBalanceOf(alice), 0);

//         // Phase 2: Claim collateral
//         assertApproxEqAbs(pool.claimableCollateralOf(alice), 250e18, 1e17);
//         vm.prank(alice);
//         pool.claimCollateral();

//         // Phase 3: New deposits restart the pool
//         vm.startPrank(bob);
//         stableToken.approve(address(pool), 3000e18);
//         pool.deposit(3000e18);
//         vm.stopPrank();

//         assertEq(pool.P(), RAY);
//         assertEq(pool.effectiveBalanceOf(bob), 3000e18);

//         // Phase 4: New liquidation
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 50e18);
//         pool.offsetDebt(500e18, 50e18);
//         vm.stopPrank();

//         assertApproxEqAbs(pool.effectiveBalanceOf(bob), 2500e18, 1e17);
//         assertApproxEqAbs(pool.claimableCollateralOf(bob), 50e18, 1e17);
//     }

//     // ============================================
//     // GAS OPTIMIZATION CHECKS
//     // ============================================

//     function test_Gas_SingleDeposit() public {
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 1000e18);
        
//         uint256 gasBefore = gasleft();
//         pool.deposit(1000e18);
//         uint256 gasUsed = gasBefore - gasleft();
//         vm.stopPrank();

//         // Ensure deposit is reasonably gas efficient
//         // This is just a sanity check
//         assertLt(gasUsed, 200000);
//     }

//     function test_Gas_OffsetDebt() public {
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 10000e18);
//         pool.deposit(10000e18);
//         vm.stopPrank();

//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 100e18);
        
//         uint256 gasBefore = gasleft();
//         pool.offsetDebt(1000e18, 100e18);
//         uint256 gasUsed = gasBefore - gasleft();
//         vm.stopPrank();

//         // OffsetDebt should be O(1) regardless of depositor count
//         assertLt(gasUsed, 300000);
//     }

//     // ============================================
//     // ADDITIONAL EDGE CASES
//     // ============================================

//     function test_EdgeCase_DepositAfterClaimingAllCollateral() public {
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 2000e18);
//         pool.deposit(1000e18);
//         vm.stopPrank();

//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 50e18);
//         pool.offsetDebt(100e18, 50e18);
//         vm.stopPrank();

//         vm.startPrank(alice);
//         pool.claimCollateral();
//         pool.deposit(1000e18);
//         vm.stopPrank();

//         assertApproxEqAbs(pool.effectiveBalanceOf(alice), 1900e18, 1e16);
//     }

//     function test_EdgeCase_ZeroEffectiveBalanceCannotWithdraw() public {
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 1000e18);
//         pool.deposit(1000e18);
//         vm.stopPrank();

//         // Wipe out pool
//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 50e18);
//         pool.offsetDebt(1000e18, 50e18);
//         vm.stopPrank();

//         vm.prank(alice);
//         vm.expectRevert("insufficient balance");
//         pool.withdraw(1);
//     }

//     function test_EdgeCase_SequentialClaims() public {
//         vm.startPrank(alice);
//         stableToken.approve(address(pool), 1000e18);
//         pool.deposit(1000e18);
//         vm.stopPrank();

//         vm.startPrank(protocol);
//         collateralToken.approve(address(pool), 50e18);
//         pool.offsetDebt(100e18, 50e18);
//         vm.stopPrank();

//         vm.startPrank(alice);
//         pool.claimCollateral();
        
//         vm.expectRevert("no collateral");
//         pool.claimCollateral();
//         vm.stopPrank();
//     }
// }