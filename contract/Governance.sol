// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TradeFiToken.sol";

/**
 * @title Governance
 * @dev A simple governance contract for the TradeFi protocol.
 * Based on OpenZeppelin Governor and Compound Governor Bravo.
 */
contract Governance {
    TradeFiToken public token;

    uint256 public constant VOTING_DELAY = 1; // 1 block
    uint256 public constant VOTING_PERIOD = 5760; // ~1 day in blocks
    uint256 public proposalThreshold = 10000 * 1e18; // 10,000 TFT to create a proposal
    uint256 public quorumVotes = 400000 * 1e18; // 4% of total supply (assuming 10M)

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
        mapping(address => Receipt) receipts;
    }

    struct Receipt {
        bool hasVoted;
        bool support;
        uint96 votes;
    }

    uint public proposalCount;
    mapping(uint => Proposal) public proposals;

    event ProposalCreated(uint id, address proposer, address[] targets, uint[] values, string[] signatures, bytes[] calldatas, uint startBlock, uint endBlock, string description);
    event VoteCast(address indexed voter, uint proposalId, bool support, uint votes);
    event ProposalExecuted(uint id);

    constructor(address _tokenAddress) {
        token = TradeFiToken(_tokenAddress);
    }

    function propose(address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas, string memory description) public returns (uint) {
        require(token.balanceOf(msg.sender) >= proposalThreshold, "Proposer votes below threshold");

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

    function castVote(uint proposalId, bool support) public {
        Proposal storage proposal = proposals[proposalId];
        require(state(proposalId) == State.Active, "Voting is not active");
        
        Receipt storage receipt = proposal.receipts[msg.sender];
        require(!receipt.hasVoted, "Voter already voted");
        
        uint96 votes = uint96(token.balanceOf(msg.sender));
        
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

    function execute(uint proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        require(state(proposalId) == State.Succeeded, "Proposal not successful");
        require(!proposal.executed, "Proposal already executed");
        
        proposal.executed = true;
        
        for (uint i = 0; i < proposal.targets.length; i++) {
            (bool success, ) = proposal.targets[i].call{value: proposal.values[i]}(
                abi.encodePacked(bytes4(keccak256(bytes(proposal.signatures[i]))), proposal.calldatas[i])
            );
            require(success, "Execution failed");
        }

        emit ProposalExecuted(proposalId);
    }

    enum State { Pending, Active, Succeeded, Defeated, Executed }

    function state(uint proposalId) public view returns (State) {
        Proposal storage p = proposals[proposalId];
        if (p.executed) return State.Executed;
        if (block.number <= p.startBlock) return State.Pending;
        if (block.number <= p.endBlock) return State.Active;
        if (p.forVotes > p.againstVotes && p.forVotes >= quorumVotes) return State.Succeeded;
        return State.Defeated;
    }
}