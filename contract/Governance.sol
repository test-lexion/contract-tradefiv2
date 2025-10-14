// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TradeFiToken.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Governance
 * @dev A secure governance contract for the TradeFi protocol.
 * Based on OpenZeppelin Governor and Compound Governor Bravo with additional security features.
 */
contract Governance is ReentrancyGuard, Ownable {
    TradeFiToken public token;

    uint256 public constant VOTING_DELAY = 1; // 1 block
    uint256 public constant VOTING_PERIOD = 5760; // ~1 day in blocks
    uint256 public proposalThreshold = 10000 * 1e18; // 10,000 TFT to create a proposal
    uint256 public quorumVotes = 400000 * 1e18; // 4% of total supply (assuming 10M)
    
    // Timelock parameters
    uint256 public constant MIN_DELAY = 2 days; // Minimum delay before execution
    uint256 public constant MAX_DELAY = 30 days; // Maximum delay before expiration
    
    // Guardian can cancel malicious proposals
    address public guardian;
    
    // Emergency pause mechanism
    bool public paused = false;

    struct Proposal {
        uint id;
        address proposer;
        address[] targets;
        uint[] values;
        string[] signatures;
        bytes[] calldatas;
        uint startBlock;
        uint endBlock;
        uint forVotes;
        uint againstVotes;
        bool executed;
        bool canceled;
        uint256 eta; // Estimated Time of Arrival for execution
        mapping(address => Receipt) receipts;
    }

    struct Receipt {
        bool hasVoted;
        bool support;
        uint96 votes;
    }

    uint public proposalCount;
    mapping(uint => Proposal) public proposals;
    
    // Proposal validation
    mapping(bytes32 => bool) public queuedTransactions;

    event ProposalCreated(uint id, address proposer, address[] targets, uint[] values, string[] signatures, bytes[] calldatas, uint startBlock, uint endBlock, string description);
    event VoteCast(address indexed voter, uint proposalId, bool support, uint votes);
    event ProposalQueued(uint id, uint256 eta);
    event ProposalExecuted(uint id);
    event ProposalCanceled(uint id);
    event GuardianChanged(address indexed newGuardian);
    event PauseChanged(bool paused);
    
    modifier whenNotPaused() {
        require(!paused, "Governance is paused");
        _;
    }
    
    modifier onlyGuardian() {
        require(msg.sender == guardian, "Only guardian can call this");
        _;
    }

    constructor(address _tokenAddress) Ownable(msg.sender) {
        token = TradeFiToken(_tokenAddress);
        guardian = msg.sender; // Initial guardian is deployer
    }

    function propose(
        address[] memory targets, 
        uint[] memory values, 
        string[] memory signatures, 
        bytes[] memory calldatas, 
        string memory description
    ) public whenNotPaused returns (uint) {
        require(token.balanceOf(msg.sender) >= proposalThreshold, "Proposer votes below threshold");
        require(targets.length > 0, "Must provide at least one target");
        require(targets.length == values.length && targets.length == signatures.length && targets.length == calldatas.length, 
                "Proposal arrays length mismatch");
        require(targets.length <= 10, "Too many actions in proposal"); // Limit to prevent gas issues
        
        // Additional validation for proposal safety
        for (uint i = 0; i < targets.length; i++) {
            require(targets[i] != address(0), "Invalid target address");
            // Prevent proposals from calling governance contract itself recursively
            require(targets[i] != address(this), "Cannot target governance contract");
        }

        uint startBlock = block.number + VOTING_DELAY;
        uint endBlock = startBlock + VOTING_PERIOD;

        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.proposer = msg.sender;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.signatures = signatures;
        newProposal.calldatas = calldatas;
        newProposal.startBlock = startBlock;
        newProposal.endBlock = endBlock;

        emit ProposalCreated(proposalCount, msg.sender, targets, values, signatures, calldatas, startBlock, endBlock, description);
        return proposalCount;
    }

    function castVote(uint proposalId, bool support) public whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        require(state(proposalId) == State.Active, "Voting is not active");
        
        Receipt storage receipt = proposal.receipts[msg.sender];
        require(!receipt.hasVoted, "Voter already voted");
        
        uint96 votes = uint96(token.balanceOf(msg.sender));
        require(votes > 0, "No voting power");
        
        if (support) {
            proposal.forVotes += votes;
        } else {
            proposal.againstVotes += votes;
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        emit VoteCast(msg.sender, proposalId, support, votes);
    }
    
    /**
     * @dev Queue a successful proposal for execution after timelock
     */
    function queue(uint proposalId) public {
        require(state(proposalId) == State.Succeeded, "Proposal not successful");
        Proposal storage proposal = proposals[proposalId];
        require(proposal.eta == 0, "Proposal already queued");
        
        uint256 eta = block.timestamp + MIN_DELAY;
        proposal.eta = eta;
        
        // Queue each transaction
        for (uint i = 0; i < proposal.targets.length; i++) {
            bytes32 txHash = keccak256(abi.encode(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                eta
            ));
            queuedTransactions[txHash] = true;
        }
        
        emit ProposalQueued(proposalId, eta);
    }

    function execute(uint proposalId) public nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(state(proposalId) == State.Queued, "Proposal not queued");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.canceled, "Proposal was canceled");
        require(block.timestamp >= proposal.eta, "Timelock not expired");
        require(block.timestamp <= proposal.eta + MAX_DELAY, "Transaction stale");
        
        proposal.executed = true;
        
        for (uint i = 0; i < proposal.targets.length; i++) {
            bytes32 txHash = keccak256(abi.encode(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            ));
            require(queuedTransactions[txHash], "Transaction not queued");
            
            // Clear the queued transaction
            queuedTransactions[txHash] = false;
            
            bytes memory callData;
            if (bytes(proposal.signatures[i]).length == 0) {
                callData = proposal.calldatas[i];
            } else {
                callData = abi.encodePacked(bytes4(keccak256(bytes(proposal.signatures[i]))), proposal.calldatas[i]);
            }
            
            (bool success, ) = proposal.targets[i].call{value: proposal.values[i]}(callData);
            require(success, "Execution failed");
        }

        emit ProposalExecuted(proposalId);
    }
    
    /**
     * @dev Cancel a proposal (only guardian or proposer can cancel)
     */
    function cancel(uint proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Cannot cancel executed proposal");
        require(!proposal.canceled, "Proposal already canceled");
        require(
            msg.sender == guardian || 
            msg.sender == proposal.proposer || 
            token.balanceOf(proposal.proposer) < proposalThreshold,
            "Not authorized to cancel"
        );
        
        proposal.canceled = true;
        
        // Clear queued transactions if any
        if (proposal.eta > 0) {
            for (uint i = 0; i < proposal.targets.length; i++) {
                bytes32 txHash = keccak256(abi.encode(
                    proposal.targets[i],
                    proposal.values[i],
                    proposal.signatures[i],
                    proposal.calldatas[i],
                    proposal.eta
                ));
                queuedTransactions[txHash] = false;
            }
        }
        
        emit ProposalCanceled(proposalId);
    }

    enum State { Pending, Active, Succeeded, Defeated, Queued, Executed, Canceled }

    function state(uint proposalId) public view returns (State) {
        Proposal storage p = proposals[proposalId];
        
        if (p.canceled) return State.Canceled;
        if (p.executed) return State.Executed;
        if (p.eta > 0 && block.timestamp >= p.eta) return State.Queued;
        if (block.number <= p.startBlock) return State.Pending;
        if (block.number <= p.endBlock) return State.Active;
        if (p.forVotes > p.againstVotes && p.forVotes >= quorumVotes) return State.Succeeded;
        return State.Defeated;
    }
    
    // --- Admin Functions ---
    
    /**
     * @dev Update proposal threshold (only governance can call this)
     */
    function setProposalThreshold(uint256 _newThreshold) external {
        require(msg.sender == address(this), "Only governance can update");
        require(_newThreshold > 0, "Threshold must be positive");
        proposalThreshold = _newThreshold;
    }
    
    /**
     * @dev Update quorum votes (only governance can call this)
     */
    function setQuorumVotes(uint256 _newQuorum) external {
        require(msg.sender == address(this), "Only governance can update");
        require(_newQuorum > 0, "Quorum must be positive");
        quorumVotes = _newQuorum;
    }
    
    /**
     * @dev Change guardian (only current guardian or governance)
     */
    function setGuardian(address _newGuardian) external {
        require(msg.sender == guardian || msg.sender == address(this), "Not authorized");
        require(_newGuardian != address(0), "Invalid guardian address");
        guardian = _newGuardian;
        emit GuardianChanged(_newGuardian);
    }
    
    /**
     * @dev Emergency pause (only guardian)
     */
    function setPaused(bool _paused) external onlyGuardian {
        paused = _paused;
        emit PauseChanged(_paused);
    }
    
    /**
     * @dev Get proposal details
     */
    function getProposal(uint proposalId) external view returns (
        address proposer,
        uint256 eta,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        uint256 startBlock,
        uint256 endBlock,
        uint256 forVotes,
        uint256 againstVotes,
        bool executed,
        bool canceled
    ) {
        Proposal storage p = proposals[proposalId];
        return (
            p.proposer,
            p.eta,
            p.targets,
            p.values,
            p.signatures,
            p.calldatas,
            p.startBlock,
            p.endBlock,
            p.forVotes,
            p.againstVotes,
            p.executed,
            p.canceled
        );
    }
}