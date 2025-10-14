// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contract/TradeFiToken.sol";
import "../contract/AssetVault.sol";
import "../contract/SpotExchange.sol";
import "../contract/StakingRewards.sol";
import "../contract/Governance.sol";

/**
 * @title DeployTradeFi
 * @dev Comprehensive deployment script for the complete TradeFi protocol
 */
contract DeployTradeFi is Script {
    
    // Deployment configuration
    struct DeploymentConfig {
        address deployer;
        address feeWallet;
        address emergencyAdmin;
        address guardian;
        uint256 initialSupply;
        uint256 proposalThreshold;
        uint256 quorumVotes;
    }
    
    // Deployed contract addresses
    struct DeployedContracts {
        address tradeFiToken;
        address assetVault;
        address spotExchange;
        address stakingRewards;
        address governance;
    }
    
    function run() external returns (DeployedContracts memory) {
        // Load configuration
        DeploymentConfig memory config = getConfig();
        
        vm.startBroadcast(config.deployer);
        
        // 1. Deploy TradeFiToken
        console.log("Deploying TradeFiToken...");
        TradeFiToken tradeFiToken = new TradeFiToken();
        console.log("TradeFiToken deployed at:", address(tradeFiToken));
        
        // 2. Deploy AssetVault
        console.log("Deploying AssetVault...");
        AssetVault assetVault = new AssetVault();
        console.log("AssetVault deployed at:", address(assetVault));
        
        // 3. Deploy SpotExchange
        console.log("Deploying SpotExchange...");
        SpotExchange spotExchange = new SpotExchange(
            address(assetVault),
            config.feeWallet
        );
        console.log("SpotExchange deployed at:", address(spotExchange));
        
        // 4. Deploy StakingRewards
        console.log("Deploying StakingRewards...");
        StakingRewards stakingRewards = new StakingRewards(
            address(tradeFiToken),
            address(tradeFiToken)
        );
        console.log("StakingRewards deployed at:", address(stakingRewards));
        
        // 5. Deploy Governance
        console.log("Deploying Governance...");
        Governance governance = new Governance(address(tradeFiToken));
        console.log("Governance deployed at:", address(governance));
        
        // 6. Setup initial configuration
        console.log("Setting up initial configuration...");
        setupContracts(
            config,
            tradeFiToken,
            assetVault,
            spotExchange,
            stakingRewards,
            governance
        );
        
        vm.stopBroadcast();
        
        // 7. Verify deployment
        console.log("Verifying deployment...");
        verifyDeployment(
            tradeFiToken,
            assetVault,
            spotExchange,
            stakingRewards,
            governance
        );
        
        console.log("=== DEPLOYMENT SUCCESSFUL ===");
        logDeploymentSummary(
            tradeFiToken,
            assetVault,
            spotExchange,
            stakingRewards,
            governance
        );
        
        return DeployedContracts({
            tradeFiToken: address(tradeFiToken),
            assetVault: address(assetVault),
            spotExchange: address(spotExchange),
            stakingRewards: address(stakingRewards),
            governance: address(governance)
        });
    }
    
    function getConfig() internal view returns (DeploymentConfig memory) {
        return DeploymentConfig({
            deployer: msg.sender,
            feeWallet: vm.envOr("FEE_WALLET", msg.sender),
            emergencyAdmin: vm.envOr("EMERGENCY_ADMIN", msg.sender),
            guardian: vm.envOr("GUARDIAN", msg.sender),
            initialSupply: vm.envOr("INITIAL_SUPPLY", uint256(100000000 * 1e18)), // 100M
            proposalThreshold: vm.envOr("PROPOSAL_THRESHOLD", uint256(10000 * 1e18)), // 10K
            quorumVotes: vm.envOr("QUORUM_VOTES", uint256(400000 * 1e18)) // 400K
        });
    }
    
    function setupContracts(
        DeploymentConfig memory config,
        TradeFiToken tradeFiToken,
        AssetVault assetVault,
        SpotExchange spotExchange,
        StakingRewards stakingRewards,
        Governance governance
    ) internal {
        
        // Setup AssetVault
        assetVault.setAuthorizedContract(address(spotExchange), true);
        assetVault.setEmergencyAdmin(config.emergencyAdmin);
        
        // Setup SpotExchange
        spotExchange.setPriceUpdater(config.deployer, true);
        
        // Setup Governance
        governance.setGuardian(config.guardian);
        
        // Setup TradeFiToken governance
        tradeFiToken.transferGovernance(address(governance));
        
        // Transfer ownership to governance (optional - can be done later)
        // Uncomment these lines if you want to immediately transfer ownership
        // assetVault.transferOwnership(address(governance));
        // spotExchange.transferOwnership(address(governance));
        // stakingRewards.transferOwnership(address(governance));
        
        console.log("Initial configuration completed");
    }
    
    function verifyDeployment(
        TradeFiToken tradeFiToken,
        AssetVault assetVault,
        SpotExchange spotExchange,
        StakingRewards stakingRewards,
        Governance governance
    ) internal view {
        // Verify TradeFiToken
        require(tradeFiToken.totalSupply() > 0, "TradeFiToken: No initial supply");
        require(tradeFiToken.governance() == address(governance), "TradeFiToken: Governance not set");
        
        // Verify AssetVault
        require(assetVault.authorizedContracts(address(spotExchange)), "AssetVault: SpotExchange not authorized");
        
        // Verify SpotExchange
        require(address(spotExchange.assetVault()) == address(assetVault), "SpotExchange: Vault not set");
        
        // Verify StakingRewards
        require(address(stakingRewards.stakingToken()) == address(tradeFiToken), "StakingRewards: Wrong staking token");
        
        // Verify Governance
        require(address(governance.token()) == address(tradeFiToken), "Governance: Wrong token");
        
        console.log("All contracts verified successfully");
    }
    
    function logDeploymentSummary(
        TradeFiToken tradeFiToken,
        AssetVault assetVault,
        SpotExchange spotExchange,
        StakingRewards stakingRewards,
        Governance governance
    ) internal view {
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("TradeFiToken:", address(tradeFiToken));
        console.log("AssetVault:", address(assetVault));
        console.log("SpotExchange:", address(spotExchange));
        console.log("StakingRewards:", address(stakingRewards));
        console.log("Governance:", address(governance));
        console.log("\n=== CONFIGURATION ===");
        console.log("TFT Total Supply:", tradeFiToken.totalSupply() / 1e18, "tokens");
        console.log("TFT Max Supply:", tradeFiToken.maxSupply() / 1e18, "tokens");
        console.log("Governance Address:", tradeFiToken.governance());
        console.log("Governance Active:", tradeFiToken.governanceActive());
        console.log("=========================\n");
    }
}