# Foundry Setup for TradeFi Protocol

This project uses [Foundry](https://book.getfoundry.sh/) for smart contract development, testing, and deployment.

## Installation

1. **Install Foundry**
   ```powershell
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```
   Or download from [Foundry releases](https://github.com/foundry-rs/foundry/releases).

2. **Initialize Foundry in your project**
   ```powershell
   forge init
   ```
   This will create a `foundry.toml` file and set up the directory structure.

3. **Install dependencies**
   ```powershell
   forge install foundry-rs/forge-std
   forge install OpenZeppelin/openzeppelin-contracts
   ```

## Usage

- **Build contracts**
  ```powershell
  forge build
  ```

- **Run tests**
  ```powershell
  forge test -vvv
  ```

- **Deploy contracts**
  ```powershell
  forge script scripts/Deploy.s.sol:DeployTradeFi --rpc-url <YOUR_RPC_URL> --broadcast
  ```

## Configuration

See `foundry.toml` for project settings. Edit `.env` for environment variables.

## Directory Structure

- `contract/` — Solidity contracts
- `test/` — Foundry test files
- `scripts/` — Deployment scripts
- `lib/` — External libraries

## More Info
- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
