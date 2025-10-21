# Trade Protocol

A comprehensive DeFi protocol built on Ethereum, featuring governance, staking, spot trading, and asset management with enhanced security features.

## 📋 Overview

The TradeFi Protocol consists of 5 interconnected smart contracts:

- **TradeFiToken (TFT)**: Governance token with delegation and snapshot capabilities
- **AssetVault**: Secure custody and management of protocol assets
- **SpotExchange**: Decentralized spot trading with slippage protection
- **StakingRewards**: Multi-tier staking system with reward boosts
- **Governance**: Timelock-secured governance with proposal validation

## 🚀 Key Features

### 🔐 Security First
- ✅ Comprehensive access controls
- ✅ Emergency pause mechanisms
- ✅ Timelock governance with guardian protection
- ✅ Slippage protection on trades
- ✅ Reentrancy protection across all contracts

### 🏛️ Advanced Governance
- ✅ Token delegation system
- ✅ Historical voting power snapshots
- ✅ Proposal validation and timelock execution
- ✅ Guardian emergency controls
- ✅ Governance-controlled minting

### 💰 Multi-Tier Staking
- ✅ 4 staking tiers with increasing rewards (1x to 1.5x multipliers)
- ✅ Early withdrawal penalties
- ✅ Automatic reward compounding
- ✅ Lock periods for higher tiers

### 📈 Spot Trading
- ✅ Multi-token support with proper decimal handling
- ✅ Gas-efficient internal settlement
- ✅ Authorized price updater system
- ✅ Trading fee collection

## 📊 Contract Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   TradeFiToken  │    │   Governance    │    │  StakingRewards │
│      (TFT)      │◄──►│                 │◄──►│                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                       ▲                       ▲
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   AssetVault    │◄──►│  SpotExchange   │    │   Emergency     │
│                 │    │                 │    │   Controls      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🛠️ Installation & Setup

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Git](https://git-scm.com/)
- [Node.js](https://nodejs.org/) (optional, for additional tooling)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/contract-tradefiv2.git
   cd contract-tradefiv2
   ```

2. **Install dependencies**
   ```bash
   forge install
   ```

3. **Set up environment**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

4. **Compile contracts**
   ```bash
   forge build
   ```

5. **Run tests**
   ```bash
   forge test
   ```

## 🧪 Testing

### Run all tests
```bash
forge test -vvv
```

### Run specific test file
```bash
forge test --match-path test/TradeFiIntegration.t.sol -vvv
```

### Run with gas reporting
```bash
forge test --gas-report
```

### Coverage report
```bash
forge coverage
```

## 🚀 Deployment

### Local Deployment (Anvil)
```bash
# Start local node
anvil

# Deploy contracts
forge script scripts/Deploy.s.sol:DeployTradeFi --rpc-url http://localhost:8545 --broadcast
```

### Testnet Deployment
```bash
# Deploy to Sepolia
./scripts/deploy.sh --network sepolia

# Deploy with verification
./scripts/deploy.sh --network sepolia --verify
```

### Mainnet Deployment
```bash
# Dry run first
./scripts/deploy.sh --network mainnet --dry-run

# Actual deployment
./scripts/deploy.sh --network mainnet
```

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DEPLOYER_PRIVATE_KEY` | Private key for deployment | Required |
| `FEE_WALLET` | Address to receive protocol fees | Deployer address |
| `EMERGENCY_ADMIN` | Emergency admin address | Deployer address |
| `GUARDIAN` | Governance guardian address | Deployer address |
| `INITIAL_SUPPLY` | Initial token supply (wei) | 100M tokens |
| `PROPOSAL_THRESHOLD` | Min tokens to create proposal | 10K tokens |
| `QUORUM_VOTES` | Min votes for proposal success | 400K tokens |

### Post-Deployment Setup

1. **Configure Asset Vault**
   ```solidity
   assetVault.setAuthorizedContract(spotExchange, true);
   assetVault.setEmergencyAdmin(emergencyAdmin);
   ```

2. **Setup Price Updaters**
   ```solidity
   spotExchange.setPriceUpdater(oracleAddress, true);
   ```

3. **Transfer Governance**
   ```solidity
   tradeFiToken.transferGovernance(governanceAddress);
   tradeFiToken.activateGovernance(); // Irreversible!
   ```

## 📝 Usage Examples

### Staking Tokens
```solidity
// Approve and stake tokens
tradeFiToken.approve(stakingRewards, amount);
stakingRewards.stake(amount);

// Check tier and rewards
(uint256 tierIndex, uint256 boost) = stakingRewards.getQualifiedTier(amount);
uint256 earned = stakingRewards.earned(user);

// Claim or compound rewards
stakingRewards.claimReward();
stakingRewards.compound(); // Auto-restake rewards
```

### Trading Assets
```solidity
// Deposit assets to vault
token.approve(assetVault, amount);
assetVault.deposit(tokenAddress, amount);

// Get trading quote
(uint256 amountOut, uint256 fee, uint256 amountAfterFee) = 
    spotExchange.getQuote(tokenA, tokenB, amountIn);

// Execute trade with slippage protection
spotExchange.executeTrade(tokenA, tokenB, amountIn, minAmountOut);
```

### Governance Participation
```solidity
// Delegate voting power
tradeFiToken.delegate(delegateAddress);

// Create proposal
uint256 proposalId = governance.propose(
    targets, values, signatures, calldatas, description
);

// Vote on proposal
governance.castVote(proposalId, true); // true for support

// Queue and execute
governance.queue(proposalId);
// Wait for timelock...
governance.execute(proposalId);
```

## 🔍 Security Considerations

### Implemented Protections
- ✅ Reentrancy guards on all state-changing functions
- ✅ Access control with role-based permissions
- ✅ Integer overflow protection (Solidity 0.8+)
- ✅ Emergency pause mechanisms
- ✅ Timelock governance with 2-day minimum delay
- ✅ Guardian can cancel malicious proposals

### Best Practices
- Regular security audits recommended
- Use multi-signature wallets for admin functions
- Monitor for unusual activity
- Keep emergency admin keys secure and offline
- Test all governance proposals on testnets first

## 📜 Contract Addresses

### Mainnet (TO BE DEPLOYED)
- TradeFiToken: `TBD`
- AssetVault: `TBD`
- SpotExchange: `TBD`
- StakingRewards: `TBD`
- Governance: `TBD`

### Sepolia Testnet
- TradeFiToken: `0x...`
- AssetVault: `0x...`
- SpotExchange: `0x...`
- StakingRewards: `0x...`
- Governance: `0x...`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- Create an issue for bug reports
- Join our [Discord](https://discord.gg/tradefi) for discussions
- Check our [documentation](https://docs.tradefi.com) for detailed guides

## 🔗 Links

- [Website](https://tradefi.com)
- [Documentation](https://docs.tradefi.com)
- [Discord](https://discord.gg/tradefi)
- [Twitter](https://twitter.com/tradefi)

---

**⚠️ Disclaimer**: This software is provided as-is and has not been audited. Use at your own risk in production environments.
