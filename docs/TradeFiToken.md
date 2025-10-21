# TradeFiToken.sol

## Purpose
ERC20 token for the TradeFi protocol, used for governance and staking rewards. Includes delegation, snapshots, and governance-controlled minting.

## Key Features
- ERC20 standard
- Delegation and voting power
- Governance-controlled minting/burning
- Snapshot voting

## Security
- Only owner/governance can mint/burn
- ReentrancyGuard on mint

## Improvements
- Move all admin controls to governance
- Add more tests for delegation and snapshots
