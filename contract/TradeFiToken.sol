// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TradeFiToken (TFT)
 * @dev Enhanced ERC20 token for the TradeFi platform with governance features.
 * Includes delegation, snapshots, and governance-controlled minting.
 */
contract TradeFiToken is ERC20, Ownable, ReentrancyGuard {
    
    // Delegation and voting power
    struct Checkpoint {
        uint256 fromBlock;
        uint256 votes;
    }
    
    mapping(address => address) public delegates;
    mapping(address => Checkpoint[]) public checkpoints;
    mapping(address => uint256) public numCheckpoints;
    
    // Governance controls
    address public governance;
    bool public governanceActive = false;
    
    // Minting controls
    uint256 public maxSupply = 1000000000 * 1e18; // 1 billion max supply
    uint256 public mintingAllowedAfter; // Timestamp after which minting is allowed
    uint256 public constant MINIMUM_TIME_BETWEEN_MINTS = 365 days; // 1 year between mints
    uint256 public constant MINT_CAP = 200000000 * 1e18; // 200M max mint per year (20% of max supply)
    
    // Events
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);
    event GovernanceTransferred(address indexed previousGovernance, address indexed newGovernance);
    event GovernanceActivated();
    constructor() ERC20("TradeFi Token", "TFT") Ownable(msg.sender) {
        // Initial supply to deployer/treasury
        _mint(msg.sender, 100000000 * (10**decimals())); // 100M initial supply
        
        // Set up initial delegation (self-delegate)
        delegates[msg.sender] = msg.sender;
        _writeCheckpoint(msg.sender, 0, balanceOf(msg.sender));
        
        // Allow minting after 1 year from deployment
        mintingAllowedAfter = block.timestamp + MINIMUM_TIME_BETWEEN_MINTS;
    }
    
    /**
     * @dev Override transfer to update voting power
     */
    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
        _updateVotes(from, to, value);
    }
    
    /**
     * @dev Delegate voting power to another address
     */
    function delegate(address delegatee) external {
        return _delegate(msg.sender, delegatee);
    }
    
    /**
     * @dev Get current voting power of an address
     */
    function getCurrentVotes(address account) external view returns (uint256) {
        uint256 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }
    
    /**
     * @dev Get voting power at a specific block
     */
    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint256) {
        require(blockNumber < block.number, "TFT: not yet determined");
        
        uint256 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }
        
        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }
        
        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }
        
        uint256 lower = 0;
        uint256 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    /**
     * @dev Creates new tokens. Can be called by owner or governance.
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external nonReentrant {
        require(msg.sender == owner() || (governanceActive && msg.sender == governance), "Not authorized to mint");
        require(totalSupply() + amount <= maxSupply, "Exceeds max supply");
        require(block.timestamp >= mintingAllowedAfter, "Minting not allowed yet");
        require(amount <= MINT_CAP, "Exceeds mint cap");
        
        _mint(to, amount);
        
        // Set next allowed minting time
        mintingAllowedAfter = block.timestamp + MINIMUM_TIME_BETWEEN_MINTS;
    }
    
    /**
     * @dev Governance-controlled burn function
     */
    function burn(uint256 amount) external {
        require(msg.sender == governance || msg.sender == owner(), "Not authorized to burn");
        _burn(msg.sender, amount);
    }
    
    /**
     * @dev Burn tokens from a specific address (requires allowance)
     */
    function burnFrom(address account, uint256 amount) external {
        require(msg.sender == governance || msg.sender == owner(), "Not authorized to burn");
        uint256 currentAllowance = allowance(account, msg.sender);
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        _approve(account, msg.sender, currentAllowance - amount);
        _burn(account, amount);
    }
    
    /**
     * @dev Transfer governance to a new address (typically the Governance contract)
     */
    function transferGovernance(address newGovernance) external onlyOwner {
        require(newGovernance != address(0), "Invalid governance address");
        address oldGovernance = governance;
        governance = newGovernance;
        emit GovernanceTransferred(oldGovernance, newGovernance);
    }
    
    /**
     * @dev Activate governance (irreversible)
     */
    function activateGovernance() external onlyOwner {
        require(governance != address(0), "Governance not set");
        governanceActive = true;
        emit GovernanceActivated();
    }
    
    /**
     * @dev Emergency function to update max supply (only before governance activation)
     */
    function setMaxSupply(uint256 _maxSupply) external onlyOwner {
        require(!governanceActive, "Governance already active");
        require(_maxSupply >= totalSupply(), "Max supply less than current supply");
        maxSupply = _maxSupply;
    }
    
    // --- Internal Functions ---
    
    /**
     * @dev Update voting power on token transfers
     */
    function _updateVotes(address from, address to, uint256 amount) internal {
        if (from != to && amount > 0) {
            if (from != address(0)) {
                address fromDelegate = delegates[from];
                if (fromDelegate != address(0)) {
                    uint256 fromDelegateBalance = balanceOf(fromDelegate);
                    _writeCheckpoint(fromDelegate, numCheckpoints[fromDelegate], fromDelegateBalance);
                }
            }
            
            if (to != address(0)) {
                address toDelegate = delegates[to];
                if (toDelegate != address(0)) {
                    uint256 toDelegateBalance = balanceOf(toDelegate);
                    _writeCheckpoint(toDelegate, numCheckpoints[toDelegate], toDelegateBalance);
                }
            }
        }
    }
    
    /**
     * @dev Internal delegation function
     */
    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator);
        delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }
    
    /**
     * @dev Move voting power between delegates
     */
    function _moveDelegates(address srcRep, address dstRep, uint256 amount) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                uint256 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint256 srcRepNew = srcRepOld - amount;
                _writeCheckpoint(srcRep, srcRepNum, srcRepNew);
            }

            if (dstRep != address(0)) {
                uint256 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint256 dstRepNew = dstRepOld + amount;
                _writeCheckpoint(dstRep, dstRepNum, dstRepNew);
            }
        }
    }
    
    /**
     * @dev Write a new checkpoint for voting power
     */
    function _writeCheckpoint(address delegatee, uint256 nCheckpoints, uint256 newVotes) internal {
        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == block.number) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(block.number, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, nCheckpoints > 0 ? checkpoints[delegatee][nCheckpoints - 1].votes : 0, newVotes);
    }
    
    // --- View Functions ---
    
    /**
     * @dev Get delegation info for an address
     */
    function getDelegateInfo(address account) external view returns (
        address delegate,
        uint256 currentVotes,
        uint256 checkpointCount
    ) {
        return (
            delegates[account],
            numCheckpoints[account] > 0 ? checkpoints[account][numCheckpoints[account] - 1].votes : 0,
            numCheckpoints[account]
        );
    }
    
    /**
     * @dev Check if governance is ready to be activated
     */
    function isGovernanceReady() external view returns (bool) {
        return governance != address(0) && !governanceActive;
    }
}