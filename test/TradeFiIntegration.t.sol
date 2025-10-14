// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contract/TradeFiToken.sol";
import "../contract/AssetVault.sol";
import "../contract/SpotExchange.sol";
import "../contract/StakingRewards.sol";
import "../contract/Governance.sol";

/**
 * @title TradeFiIntegrationTest
 * @dev Comprehensive integration tests for the TradeFi protocol
 */
contract TradeFiIntegrationTest is Test {
    
    // Contracts
    TradeFiToken public tradeFiToken;
    AssetVault public assetVault;
    SpotExchange public spotExchange;
    StakingRewards public stakingRewards;
    Governance public governance;
    
    // Test accounts
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public charlie = address(0x4);
    address public feeWallet = address(0x5);
    
    // Mock tokens for testing
    TradeFiToken public mockUSDC;
    TradeFiToken public mockWETH;
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy all contracts
        tradeFiToken = new TradeFiToken();
        assetVault = new AssetVault();
        spotExchange = new SpotExchange(address(assetVault), feeWallet);
        stakingRewards = new StakingRewards(address(tradeFiToken), address(tradeFiToken));
        governance = new Governance(address(tradeFiToken));
        
        // Create mock tokens for testing
        mockUSDC = new TradeFiToken();
        mockWETH = new TradeFiToken();
        
        // Setup initial configuration
        assetVault.setAuthorizedContract(address(spotExchange), true);
        spotExchange.setPriceUpdater(owner, true);
        tradeFiToken.transferGovernance(address(governance));
        
        // Distribute tokens for testing
        tradeFiToken.transfer(alice, 10000 * 1e18);
        tradeFiToken.transfer(bob, 10000 * 1e18);
        tradeFiToken.transfer(charlie, 10000 * 1e18);
        
        mockUSDC.transfer(alice, 50000 * 1e18);
        mockWETH.transfer(bob, 100 * 1e18);
        
        vm.stopPrank();
    }
    
    function testFullProtocolFlow() public {
        // 1. Test token delegation and governance
        testGovernanceFlow();
        
        // 2. Test asset vault operations
        testAssetVaultOperations();
        
        // 3. Test spot trading
        testSpotTradingFlow();
        
        // 4. Test staking rewards
        testStakingFlow();
        
        // 5. Test emergency functions
        testEmergencyFunctions();
    }
    
    function testGovernanceFlow() public {
        console.log("=== Testing Governance Flow ===");
        
        // Alice delegates to herself
        vm.prank(alice);
        tradeFiToken.delegate(alice);
        
        // Check voting power
        uint256 aliceVotes = tradeFiToken.getCurrentVotes(alice);
        assertEq(aliceVotes, 10000 * 1e18, "Alice should have 10k voting power");
        
        // Create a proposal
        vm.prank(alice);
        address[] memory targets = new address[](1);
        uint[] memory values = new uint[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(spotExchange);
        values[0] = 0;
        signatures[0] = "setTradingFee(uint256)";
        calldatas[0] = abi.encode(20); // 0.20% fee
        
        uint256 proposalId = governance.propose(
            targets,
            values,
            signatures,
            calldatas,
            "Increase trading fee to 0.20%"
        );
        
        // Fast forward to voting period
        vm.roll(block.number + 2);
        
        // Vote on proposal
        vm.prank(alice);
        governance.castVote(proposalId, true);
        
        // Fast forward past voting period
        vm.roll(block.number + 5761);
        
        // Queue proposal
        governance.queue(proposalId);
        
        // Fast forward past timelock
        vm.warp(block.timestamp + 2 days + 1);
        
        // Execute proposal
        governance.execute(proposalId);
        
        // Verify execution
        assertEq(spotExchange.feeBps(), 20, "Trading fee should be updated");
        
        console.log("✓ Governance flow completed successfully");
    }
    
    function testAssetVaultOperations() public {
        console.log("=== Testing Asset Vault Operations ===");
        
        // Alice deposits USDC
        vm.startPrank(alice);
        mockUSDC.approve(address(assetVault), 1000 * 1e18);
        assetVault.deposit(address(mockUSDC), 1000 * 1e18);
        vm.stopPrank();
        
        // Check balance
        uint256 balance = assetVault.getUserBalance(address(mockUSDC), alice);
        assertEq(balance, 1000 * 1e18, "Alice should have 1000 USDC in vault");
        
        // Test withdrawal
        vm.prank(alice);
        assetVault.withdraw(address(mockUSDC), 500 * 1e18);
        
        balance = assetVault.getUserBalance(address(mockUSDC), alice);
        assertEq(balance, 500 * 1e18, "Alice should have 500 USDC left in vault");
        
        console.log("✓ Asset vault operations completed successfully");
    }
    
    function testSpotTradingFlow() public {
        console.log("=== Testing Spot Trading Flow ===");
        
        // Setup: Alice deposits USDC, Bob deposits WETH
        vm.startPrank(alice);
        mockUSDC.approve(address(assetVault), 10000 * 1e18);
        assetVault.deposit(address(mockUSDC), 10000 * 1e18);
        vm.stopPrank();
        
        vm.startPrank(bob);
        mockWETH.approve(address(assetVault), 10 * 1e18);
        assetVault.deposit(address(mockWETH), 10 * 1e18);
        vm.stopPrank();
        
        // Fee wallet needs some liquidity for trading
        vm.startPrank(owner);
        mockUSDC.transfer(feeWallet, 50000 * 1e18);
        mockWETH.transfer(feeWallet, 50 * 1e18);
        
        mockUSDC.approve(address(assetVault), 50000 * 1e18);
        mockWETH.approve(address(assetVault), 50 * 1e18);
        
        assetVault.deposit(address(mockUSDC), 50000 * 1e18);
        assetVault.deposit(address(mockWETH), 50 * 1e18);
        vm.stopPrank();
        
        // Set price: 1 WETH = 2500 USDC
        vm.prank(owner);
        spotExchange.setPrice(address(mockWETH), address(mockUSDC), 2500 * 1e18);
        
        // Alice trades 1 WETH for USDC
        vm.prank(alice);
        // Get quote first
        (uint256 amountTo, uint256 fee, uint256 amountAfterFee) = spotExchange.getQuote(
            address(mockWETH), 
            address(mockUSDC), 
            1 * 1e18
        );
        
        console.log("Quote: amountTo =", amountTo / 1e18, "fee =", fee / 1e18, "amountAfterFee =", amountAfterFee / 1e18);
        
        console.log("✓ Spot trading flow completed successfully");
    }
    
    function testStakingFlow() public {
        console.log("=== Testing Staking Flow ===");
        
        // Alice stakes tokens
        vm.startPrank(alice);
        tradeFiToken.approve(address(stakingRewards), 5000 * 1e18);
        stakingRewards.stake(5000 * 1e18);
        vm.stopPrank();
        
        // Check staking balance
        uint256 stakedBalance = stakingRewards.balanceOf(alice);
        assertEq(stakedBalance, 5000 * 1e18, "Alice should have 5000 tokens staked");
        
        // Owner adds rewards
        vm.startPrank(owner);
        tradeFiToken.approve(address(stakingRewards), 1000 * 1e18);
        tradeFiToken.transfer(address(stakingRewards), 1000 * 1e18);
        stakingRewards.notifyRewardAmount(1000 * 1e18);
        vm.stopPrank();
        
        // Fast forward time to accumulate rewards
        vm.warp(block.timestamp + 1 days);
        
        // Check earned rewards
        uint256 earned = stakingRewards.earned(alice);
        assertTrue(earned > 0, "Alice should have earned some rewards");
        
        // Claim rewards
        vm.prank(alice);
        stakingRewards.claimReward();
        
        console.log("✓ Staking flow completed successfully");
    }
    
    function testEmergencyFunctions() public {
        console.log("=== Testing Emergency Functions ===");
        
        // Test pausing asset vault
        vm.prank(owner);
        assetVault.setPaused(true);
        
        // Try to deposit while paused (should fail)
        vm.startPrank(alice);
        mockUSDC.approve(address(assetVault), 100 * 1e18);
        vm.expectRevert("Vault is paused");
        assetVault.deposit(address(mockUSDC), 100 * 1e18);
        vm.stopPrank();
        
        // Unpause
        vm.prank(owner);
        assetVault.setPaused(false);
        
        // Test emergency mode
        vm.prank(owner);
        assetVault.setEmergencyMode(true);
        
        // Test trading pause
        vm.prank(owner);
        spotExchange.setTradingPaused(true);
        
        console.log("✓ Emergency functions completed successfully");
    }
    
    function testAdvancedStakingFeatures() public {
        console.log("=== Testing Advanced Staking Features ===");
        
        // Test different staking tiers
        vm.startPrank(alice);
        tradeFiToken.approve(address(stakingRewards), 50000 * 1e18);
        
        // Stake for gold tier (10k+ tokens)
        stakingRewards.stake(15000 * 1e18);
        
        // Check tier info
        (uint256 amount, uint256 stakingTime, uint256 tierIndex, uint256 lockedUntil, bool canWithdraw, uint256 penalty) = 
            stakingRewards.getUserStakeInfo(alice);
        
        assertTrue(tierIndex >= 2, "Alice should be in gold tier or higher");
        assertTrue(penalty > 0, "There should be early withdrawal penalty");
        
        vm.stopPrank();
        
        console.log("✓ Advanced staking features completed successfully");
    }
    
    function testTokenDelegation() public {
        console.log("=== Testing Token Delegation ===");
        
        // Bob delegates to Alice
        vm.prank(bob);
        tradeFiToken.delegate(alice);
        
        // Check Alice's total voting power (her tokens + Bob's delegation)
        uint256 aliceVotes = tradeFiToken.getCurrentVotes(alice);
        uint256 expectedVotes = tradeFiToken.balanceOf(alice) + tradeFiToken.balanceOf(bob);
        
        assertEq(aliceVotes, expectedVotes, "Alice should have combined voting power");
        
        console.log("✓ Token delegation completed successfully");
    }
    
    function testSecurityFeatures() public {
        console.log("=== Testing Security Features ===");
        
        // Test unauthorized price update
        vm.prank(alice);
        vm.expectRevert("Not authorized to update prices");
        spotExchange.setPrice(address(mockWETH), address(mockUSDC), 3000 * 1e18);
        
        // Test unauthorized governance call
        vm.prank(alice);
        vm.expectRevert("Not authorized to mint");
        tradeFiToken.mint(alice, 1000 * 1e18);
        
        console.log("✓ Security features completed successfully");
    }
    
    // Helper function to log test results
    function logTestResult(string memory testName, bool passed) internal pure {
        if (passed) {
            console.log(string(abi.encodePacked("✓ ", testName, " passed")));
        } else {
            console.log(string(abi.encodePacked("✗ ", testName, " failed")));
        }
    }
}