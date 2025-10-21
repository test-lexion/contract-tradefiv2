# StakingRewards.sol

## Purpose
Allows users to stake TradeFiToken (TFT) to earn rewards. Supports multi-tier staking, compounding, and early withdrawal penalties.

## Key Features
- Multi-tier staking system
- Reward boost multipliers
- Early withdrawal penalties
- Compounding rewards
- Pause mechanism

## Security
- ReentrancyGuard
- Owner controls for tier management

## Improvements
- Add more tests for tier upgrades/downgrades
- Move admin controls to governance
