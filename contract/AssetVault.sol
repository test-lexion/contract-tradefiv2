// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AssetVault
 * @dev Securely holds and manages user deposits of various ERC20 tokens.
 * This contract is the central repository for all protocol assets.
 */
contract AssetVault is Ownable, ReentrancyGuard {
    // Mapping: Token Address -> User Address -> Amount Deposited
    mapping(address => mapping(address => uint256)) public balances;

    // Set of authorized contracts that can call internal functions
    mapping(address => bool) public authorizedContracts;

    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    event AuthorizedContractChanged(address indexed contractAddress, bool isAuthorized);

    constructor() Ownable(msg.sender) {}

    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender], "Not an authorized contract");
        _;
    }

    /**
     * @dev Allows a user to deposit an ERC20 token into the vault.
     * The user must first approve this contract to spend their tokens.
     */
    function deposit(address _token, uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        balances[_token][msg.sender] += _amount;
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        emit Deposited(msg.sender, _token, _amount);
    }

    /**
     * @dev Allows a user to withdraw their deposited ERC20 tokens.
     */
    function withdraw(address _token, uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        uint256 userBalance = balances[_token][msg.sender];
        require(userBalance >= _amount, "Insufficient balance");

        balances[_token][msg.sender] = userBalance - _amount;
        IERC20(_token).transfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _token, _amount);
    }

    /**
     * @dev Moves balances internally without an on-chain transfer.
     * This is highly gas-efficient for trading within the protocol.
     * Can only be called by authorized contracts (e.g., the SpotExchange).
     */
    function internalTransfer(address _token, address _from, address _to, uint256 _amount) external onlyAuthorized {
        uint256 fromBalance = balances[_token][_from];
        require(fromBalance >= _amount, "Insufficient internal balance");

        balances[_token][_from] = fromBalance - _amount;
        balances[_token][_to] += _amount;
    }

    // --- Admin Functions ---
    function setAuthorizedContract(address _contract, bool _isAuthorized) public onlyOwner {
        authorizedContracts[_contract] = _isAuthorized;
        emit AuthorizedContractChanged(_contract, _isAuthorized);
    }
}