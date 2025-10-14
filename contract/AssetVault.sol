// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AssetVault
 * @dev Securely holds and manages user deposits of various ERC20 tokens.
 * This contract is the central repository for all protocol assets.
 */
contract AssetVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // Mapping: Token Address -> User Address -> Amount Deposited
    mapping(address => mapping(address => uint256)) public balances;

    // Set of authorized contracts that can call internal functions
    mapping(address => bool) public authorizedContracts;
    
    // Emergency controls
    bool public paused = false;
    bool public emergencyMode = false;
    address public emergencyAdmin;
    
    // Withdrawal limits for emergency situations
    mapping(address => uint256) public dailyWithdrawalLimits; // per token
    mapping(address => mapping(uint256 => uint256)) public dailyWithdrawn; // token -> day -> amount
    
    // Fee structure
    uint256 public depositFeeBps = 0; // Default: no deposit fee
    uint256 public withdrawalFeeBps = 0; // Default: no withdrawal fee
    address public feeRecipient;

    event Deposited(address indexed user, address indexed token, uint256 amount, uint256 fee);
    event Withdrawn(address indexed user, address indexed token, uint256 amount, uint256 fee);
    event AuthorizedContractChanged(address indexed contractAddress, bool isAuthorized);
    event EmergencyModeChanged(bool enabled);
    event PauseChanged(bool paused);
    event EmergencyAdminChanged(address indexed newAdmin);
    event WithdrawalLimitChanged(address indexed token, uint256 newLimit);
    event EmergencyWithdrawal(address indexed user, address indexed token, uint256 amount);

    modifier whenNotPaused() {
        require(!paused, "Vault is paused");
        _;
    }
    
    modifier onlyEmergencyAdmin() {
        require(msg.sender == emergencyAdmin || msg.sender == owner(), "Only emergency admin");
        _;
    }

    constructor() Ownable(msg.sender) {
        emergencyAdmin = msg.sender;
        feeRecipient = msg.sender;
    }

    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender], "Not an authorized contract");
        _;
    }

    /**
     * @dev Allows a user to deposit an ERC20 token into the vault.
     * The user must first approve this contract to spend their tokens.
     */
    function deposit(address _token, uint256 _amount) external nonReentrant whenNotPaused {
        require(_amount > 0, "Amount must be greater than 0");
        require(!emergencyMode, "Emergency mode active");
        
        // Calculate deposit fee
        uint256 fee = (_amount * depositFeeBps) / 10000;
        uint256 netAmount = _amount - fee;
        
        balances[_token][msg.sender] += netAmount;
        
        // Transfer tokens from user
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        
        // Transfer fee to recipient if any
        if (fee > 0 && feeRecipient != address(0)) {
            IERC20(_token).safeTransfer(feeRecipient, fee);
        }
        
        emit Deposited(msg.sender, _token, netAmount, fee);
    }

    /**
     * @dev Allows a user to withdraw their deposited ERC20 tokens.
     */
    function withdraw(address _token, uint256 _amount) external nonReentrant whenNotPaused {
        require(_amount > 0, "Amount must be greater than 0");
        uint256 userBalance = balances[_token][msg.sender];
        require(userBalance >= _amount, "Insufficient balance");
        
        // Check daily withdrawal limits in emergency mode
        if (emergencyMode) {
            uint256 currentDay = block.timestamp / 1 days;
            uint256 limit = dailyWithdrawalLimits[_token];
            if (limit > 0) {
                require(dailyWithdrawn[_token][currentDay] + _amount <= limit, "Daily withdrawal limit exceeded");
                dailyWithdrawn[_token][currentDay] += _amount;
            }
        }
        
        // Calculate withdrawal fee
        uint256 fee = (_amount * withdrawalFeeBps) / 10000;
        uint256 netAmount = _amount - fee;

        balances[_token][msg.sender] = userBalance - _amount;
        
        // Transfer net amount to user
        IERC20(_token).safeTransfer(msg.sender, netAmount);
        
        // Transfer fee to recipient if any
        if (fee > 0 && feeRecipient != address(0)) {
            IERC20(_token).safeTransfer(feeRecipient, fee);
        }
        
        emit Withdrawn(msg.sender, _token, netAmount, fee);
    }
    
    /**
     * @dev Emergency withdrawal function - bypasses normal withdrawal limits
     * Only available when emergency mode is active and called by user or emergency admin
     */
    function emergencyWithdraw(address _token, address _user) external nonReentrant {
        require(emergencyMode, "Emergency mode not active");
        require(msg.sender == _user || msg.sender == emergencyAdmin || msg.sender == owner(), "Not authorized");
        
        uint256 userBalance = balances[_token][_user];
        require(userBalance > 0, "No balance to withdraw");
        
        balances[_token][_user] = 0;
        IERC20(_token).safeTransfer(_user, userBalance);
        
        emit EmergencyWithdrawal(_user, _token, userBalance);
    }

    /**
     * @dev Moves balances internally without an on-chain transfer.
     * This is highly gas-efficient for trading within the protocol.
     * Can only be called by authorized contracts (e.g., the SpotExchange).
     */
    function internalTransfer(address _token, address _from, address _to, uint256 _amount) external onlyAuthorized whenNotPaused {
        require(!emergencyMode, "Emergency mode active");
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
    
    /**
     * @dev Set emergency mode - restricts operations and enables emergency withdrawals
     */
    function setEmergencyMode(bool _enabled) external onlyEmergencyAdmin {
        emergencyMode = _enabled;
        emit EmergencyModeChanged(_enabled);
    }
    
    /**
     * @dev Pause all operations except emergency withdrawals
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PauseChanged(_paused);
    }
    
    /**
     * @dev Change emergency admin
     */
    function setEmergencyAdmin(address _newAdmin) external onlyOwner {
        require(_newAdmin != address(0), "Invalid admin address");
        emergencyAdmin = _newAdmin;
        emit EmergencyAdminChanged(_newAdmin);
    }
    
    /**
     * @dev Set daily withdrawal limits for tokens (0 = no limit)
     */
    function setDailyWithdrawalLimit(address _token, uint256 _limit) external onlyOwner {
        dailyWithdrawalLimits[_token] = _limit;
        emit WithdrawalLimitChanged(_token, _limit);
    }
    
    /**
     * @dev Set deposit fee in basis points (max 5%)
     */
    function setDepositFee(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 500, "Fee cannot exceed 5%");
        depositFeeBps = _feeBps;
    }
    
    /**
     * @dev Set withdrawal fee in basis points (max 5%)
     */
    function setWithdrawalFee(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 500, "Fee cannot exceed 5%");
        withdrawalFeeBps = _feeBps;
    }
    
    /**
     * @dev Set fee recipient address
     */
    function setFeeRecipient(address _recipient) external onlyOwner {
        require(_recipient != address(0), "Invalid recipient");
        feeRecipient = _recipient;
    }
    
    /**
     * @dev Get user balance for a token
     */
    function getUserBalance(address _token, address _user) external view returns (uint256) {
        return balances[_token][_user];
    }
    
    /**
     * @dev Get today's withdrawn amount for a token
     */
    function getTodayWithdrawn(address _token) external view returns (uint256) {
        uint256 currentDay = block.timestamp / 1 days;
        return dailyWithdrawn[_token][currentDay];
    }
}