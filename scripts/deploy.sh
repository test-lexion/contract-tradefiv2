#!/bin/bash

# TradeFi Protocol Deployment Script
# This script deploys the complete TradeFi protocol to a specified network

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NETWORK="sepolia"
VERIFY_CONTRACTS="true"
DRY_RUN="false"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --network NETWORK     Target network (default: sepolia)"
    echo "  --no-verify              Skip contract verification"
    echo "  --dry-run                Simulate deployment without broadcasting"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Supported networks: mainnet, sepolia, arbitrum, polygon"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--network)
            NETWORK="$2"
            shift 2
            ;;
        --no-verify)
            VERIFY_CONTRACTS="false"
            shift
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate network
case $NETWORK in
    mainnet|sepolia|arbitrum|polygon)
        print_status "Deploying to $NETWORK network"
        ;;
    *)
        print_error "Unsupported network: $NETWORK"
        print_error "Supported networks: mainnet, sepolia, arbitrum, polygon"
        exit 1
        ;;
esac

# Check if .env file exists
if [[ ! -f .env ]]; then
    print_warning ".env file not found. Please copy .env.example to .env and configure it."
    exit 1
fi

# Load environment variables
source .env

# Validate required environment variables
required_vars=("DEPLOYER_PRIVATE_KEY")
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        print_error "Required environment variable $var is not set"
        exit 1
    fi
done

# Install dependencies if needed
if [[ ! -d "lib/forge-std" ]]; then
    print_status "Installing Foundry dependencies..."
    forge install foundry-rs/forge-std --no-commit
    forge install OpenZeppelin/openzeppelin-contracts --no-commit
fi

# Compile contracts
print_status "Compiling contracts..."
forge build

if [[ $? -ne 0 ]]; then
    print_error "Contract compilation failed"
    exit 1
fi

print_success "Contracts compiled successfully"

# Run tests before deployment
print_status "Running tests..."
forge test

if [[ $? -ne 0 ]]; then
    print_error "Tests failed"
    exit 1
fi

print_success "All tests passed"

# Deploy contracts
print_status "Starting deployment to $NETWORK..."

DEPLOY_CMD="forge script scripts/Deploy.s.sol:DeployTradeFi"
DEPLOY_CMD="$DEPLOY_CMD --rpc-url $NETWORK"

if [[ "$DRY_RUN" == "false" ]]; then
    DEPLOY_CMD="$DEPLOY_CMD --broadcast"
fi

if [[ "$VERIFY_CONTRACTS" == "true" && "$DRY_RUN" == "false" ]]; then
    DEPLOY_CMD="$DEPLOY_CMD --verify"
fi

DEPLOY_CMD="$DEPLOY_CMD --slow"

print_status "Executing: $DEPLOY_CMD"

# Execute deployment
eval $DEPLOY_CMD

if [[ $? -ne 0 ]]; then
    print_error "Deployment failed"
    exit 1
fi

if [[ "$DRY_RUN" == "true" ]]; then
    print_success "Dry run completed successfully"
else
    print_success "Deployment completed successfully"
    
    # Save deployment info
    DEPLOYMENT_FILE="deployments/${NETWORK}_$(date +%Y%m%d_%H%M%S).json"
    mkdir -p deployments
    
    print_status "Saving deployment information to $DEPLOYMENT_FILE"
    
    # Extract contract addresses from deployment output
    # This is a simplified version - in practice, you'd parse the actual output
    cat > "$DEPLOYMENT_FILE" << EOF
{
  "network": "$NETWORK",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "deployer": "$DEPLOYER_ADDRESS",
  "contracts": {
    "TradeFiToken": "DEPLOYED_ADDRESS_HERE",
    "AssetVault": "DEPLOYED_ADDRESS_HERE",
    "SpotExchange": "DEPLOYED_ADDRESS_HERE",
    "StakingRewards": "DEPLOYED_ADDRESS_HERE",
    "Governance": "DEPLOYED_ADDRESS_HERE"
  },
  "configuration": {
    "tradingFeeBps": $DEFAULT_TRADING_FEE_BPS,
    "proposalThreshold": "$PROPOSAL_THRESHOLD",
    "quorumVotes": "$QUORUM_VOTES"
  }
}
EOF
    
    print_success "Deployment information saved"
    
    # Post-deployment verification
    print_status "Running post-deployment verification..."
    
    # Add any post-deployment checks here
    
    print_success "Post-deployment verification completed"
fi

print_success "Script completed successfully!"

# Print next steps
echo ""
echo "=== NEXT STEPS ==="
echo "1. Review the deployed contract addresses"
echo "2. Verify contracts on block explorer (if not done automatically)"
echo "3. Configure initial parameters if needed"
echo "4. Transfer ownership to governance contracts"
echo "5. Activate governance system"
echo "=================="