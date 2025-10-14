// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StakingRewards
 * @dev Enhanced staking contract allowing users to stake TradeFiToken (TFT) to earn rewards.
 * Based on the Synthetix StakingRewards model with additional features.
 */
contract StakingRewards is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public stakingToken; // The token users stake (TFT)
    IERC20 public rewardsToken; // The token paid as reward (also TFT)

    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public rewardsDuration = 7 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    
    // Enhanced features
    uint256 public minimumStakingPeriod = 1 days; // Minimum time before withdrawal
    uint256 public earlyWithdrawalPenaltyBps = 500; // 5% penalty for early withdrawal
    address public penaltyRecipient;
    
    // Staking tiers with boost multipliers
    struct StakingTier {
        uint256 minAmount;      // Minimum stake for this tier
        uint256 boostMultiplier; // Multiplier in basis points (10000 = 1x)
        uint256 lockPeriod;     // Required lock period for this tier
    }
    
    StakingTier[] public stakingTiers;
    
    // User staking info
    struct UserStake {
        uint256 amount;
        uint256 stakingTime;
        uint256 tierIndex;
        uint256 lockedUntil;
    }

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => UserStake) public userStakes;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    
    // Pause mechanism
    bool public paused = false;

    event Staked(address indexed user, uint256 amount, uint256 tierIndex);
    event Withdrawn(address indexed user, uint256 amount, uint256 penalty);
    event RewardPaid(address indexed user, uint256 reward);
    event TierAdded(uint256 minAmount, uint256 boostMultiplier, uint256 lockPeriod);
    event TierUpdated(uint256 tierIndex, uint256 minAmount, uint256 boostMultiplier, uint256 lockPeriod);
    event PauseChanged(bool paused);
    event EarlyWithdrawalPenaltyChanged(uint256 penaltyBps);
    
    modifier whenNotPaused() {
        require(!paused, "Staking is paused");
        _;
    }

    constructor(address _stakingToken, address _rewardsToken) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
        penaltyRecipient = msg.sender;
        
        // Initialize default tiers
        _addTier(0, 10000, 0); // Basic tier: no minimum, 1x multiplier, no lock
        _addTier(1000 * 1e18, 11000, 7 days); // Silver: 1k tokens, 1.1x multiplier, 7 days lock
        _addTier(10000 * 1e18, 12500, 30 days); // Gold: 10k tokens, 1.25x multiplier, 30 days lock
        _addTier(100000 * 1e18, 15000, 90 days); // Platinum: 100k tokens, 1.5x multiplier, 90 days lock
    }

    // --- View Functions ---
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }
    
    function earned(address account) public view returns (uint256) {
        UserStake memory userStake = userStakes[account];
        uint256 baseReward = (_balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 + rewards[account];
        
        // Apply tier boost
        if (userStake.tierIndex < stakingTiers.length) {
            uint256 boost = stakingTiers[userStake.tierIndex].boostMultiplier;
            baseReward = (baseReward * boost) / 10000;
        }
        
        return baseReward;
    }
    
    /**
     * @dev Get the highest tier index a user qualifies for based on their stake amount
     */
    function getQualifiedTier(uint256 amount) public view returns (uint256) {
        for (uint256 i = stakingTiers.length; i > 0; i--) {
            if (amount >= stakingTiers[i - 1].minAmount) {
                return i - 1;
            }
        }
        return 0; // Default to basic tier
    }
    
    /**
     * @dev Check if user can withdraw without penalty
     */
    function canWithdrawWithoutPenalty(address account) public view returns (bool) {
        UserStake memory userStake = userStakes[account];
        return block.timestamp >= userStake.stakingTime + minimumStakingPeriod && 
               block.timestamp >= userStake.lockedUntil;
    }
    
    /**
     * @dev Calculate early withdrawal penalty
     */
    function calculatePenalty(address account, uint256 amount) public view returns (uint256) {
        if (canWithdrawWithoutPenalty(account)) {
            return 0;
        }
        return (amount * earlyWithdrawalPenaltyBps) / 10000;
    }

    // --- Core Logic ---
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) whenNotPaused {
        require(amount > 0, "Cannot stake 0");
        
        // If user is already staking, add to existing stake
        UserStake storage userStake = userStakes[msg.sender];
        uint256 newTotalAmount = _balances[msg.sender] + amount;
        
        // Determine tier based on new total amount
        uint256 newTierIndex = getQualifiedTier(newTotalAmount);
        StakingTier memory newTier = stakingTiers[newTierIndex];
        
        // Update user stake info
        userStake.amount = newTotalAmount;
        userStake.stakingTime = block.timestamp;
        userStake.tierIndex = newTierIndex;
        userStake.lockedUntil = block.timestamp + newTier.lockPeriod;
        
        _totalSupply += amount;
        _balances[msg.sender] += amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        
        emit Staked(msg.sender, amount, newTierIndex);
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        
        uint256 penalty = calculatePenalty(msg.sender, amount);
        uint256 withdrawAmount = amount - penalty;
        
        // Update user stake
        UserStake storage userStake = userStakes[msg.sender];
        userStake.amount = _balances[msg.sender] - amount;
        
        // Recalculate tier for remaining balance
        if (userStake.amount > 0) {
            uint256 newTierIndex = getQualifiedTier(userStake.amount);
            userStake.tierIndex = newTierIndex;
            userStake.lockedUntil = block.timestamp + stakingTiers[newTierIndex].lockPeriod;
        } else {
            // Reset if fully withdrawn
            userStake.tierIndex = 0;
            userStake.lockedUntil = 0;
        }
        
        _totalSupply -= amount;
        _balances[msg.sender] -= amount;
        
        // Transfer tokens
        stakingToken.safeTransfer(msg.sender, withdrawAmount);
        
        // Send penalty to recipient if applicable
        if (penalty > 0) {
            stakingToken.safeTransfer(penaltyRecipient, penalty);
        }
        
        emit Withdrawn(msg.sender, withdrawAmount, penalty);
    }

    function claimReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }
    
    /**
     * @dev Compound rewards by staking them
     */
    function compound() external nonReentrant updateReward(msg.sender) whenNotPaused {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No rewards to compound");
        
        rewards[msg.sender] = 0;
        
        // Add reward to stake
        UserStake storage userStake = userStakes[msg.sender];
        uint256 newTotalAmount = _balances[msg.sender] + reward;
        
        // Determine new tier
        uint256 newTierIndex = getQualifiedTier(newTotalAmount);
        StakingTier memory newTier = stakingTiers[newTierIndex];
        
        // Update user stake info
        userStake.amount = newTotalAmount;
        userStake.tierIndex = newTierIndex;
        userStake.lockedUntil = block.timestamp + newTier.lockPeriod;
        
        _totalSupply += reward;
        _balances[msg.sender] += reward;
        
        emit Staked(msg.sender, reward, newTierIndex);
        emit RewardPaid(msg.sender, reward);
    }

    // --- Admin Functions ---
    function notifyRewardAmount(uint256 reward) external onlyOwner updateReward(address(0)) {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / rewardsDuration;
        }
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;
    }
    
    /**
     * @dev Add a new staking tier
     */
    function addTier(uint256 _minAmount, uint256 _boostMultiplier, uint256 _lockPeriod) external onlyOwner {
        _addTier(_minAmount, _boostMultiplier, _lockPeriod);
    }
    
    /**
     * @dev Update an existing tier
     */
    function updateTier(uint256 _tierIndex, uint256 _minAmount, uint256 _boostMultiplier, uint256 _lockPeriod) external onlyOwner {
        require(_tierIndex < stakingTiers.length, "Invalid tier index");
        require(_boostMultiplier >= 5000 && _boostMultiplier <= 50000, "Invalid boost multiplier"); // 0.5x to 5x
        
        stakingTiers[_tierIndex] = StakingTier({
            minAmount: _minAmount,
            boostMultiplier: _boostMultiplier,
            lockPeriod: _lockPeriod
        });
        
        emit TierUpdated(_tierIndex, _minAmount, _boostMultiplier, _lockPeriod);
    }
    
    /**
     * @dev Set minimum staking period
     */
    function setMinimumStakingPeriod(uint256 _period) external onlyOwner {
        require(_period <= 30 days, "Period too long");
        minimumStakingPeriod = _period;
    }
    
    /**
     * @dev Set early withdrawal penalty
     */
    function setEarlyWithdrawalPenalty(uint256 _penaltyBps) external onlyOwner {
        require(_penaltyBps <= 2000, "Penalty cannot exceed 20%");
        earlyWithdrawalPenaltyBps = _penaltyBps;
        emit EarlyWithdrawalPenaltyChanged(_penaltyBps);
    }
    
    /**
     * @dev Set penalty recipient
     */
    function setPenaltyRecipient(address _recipient) external onlyOwner {
        require(_recipient != address(0), "Invalid recipient");
        penaltyRecipient = _recipient;
    }
    
    /**
     * @dev Set rewards duration
     */
    function setRewardsDuration(uint256 _duration) external onlyOwner {
        require(block.timestamp > periodFinish, "Previous rewards period must be complete");
        require(_duration > 0, "Duration must be positive");
        rewardsDuration = _duration;
    }
    
    /**
     * @dev Pause/unpause staking
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PauseChanged(_paused);
    }
    
    /**
     * @dev Emergency function to recover tokens (not staking or rewards tokens)
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        require(tokenAddress != address(stakingToken), "Cannot withdraw staking token");
        require(tokenAddress != address(rewardsToken), "Cannot withdraw rewards token");
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
    }
    
    // --- Internal Helper Functions ---
    function rewardPerToken() internal view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (rewardRate * (lastTimeRewardApplicable() - lastUpdateTime) * 1e18) / _totalSupply;
    }

    function lastTimeRewardApplicable() internal view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }
    
    function _addTier(uint256 _minAmount, uint256 _boostMultiplier, uint256 _lockPeriod) internal {
        require(_boostMultiplier >= 5000 && _boostMultiplier <= 50000, "Invalid boost multiplier"); // 0.5x to 5x
        
        stakingTiers.push(StakingTier({
            minAmount: _minAmount,
            boostMultiplier: _boostMultiplier,
            lockPeriod: _lockPeriod
        }));
        
        emit TierAdded(_minAmount, _boostMultiplier, _lockPeriod);
    }
    
    // --- View Functions for Tiers ---
    function getTierCount() external view returns (uint256) {
        return stakingTiers.length;
    }
    
    function getTier(uint256 _index) external view returns (uint256 minAmount, uint256 boostMultiplier, uint256 lockPeriod) {
        require(_index < stakingTiers.length, "Invalid tier index");
        StakingTier memory tier = stakingTiers[_index];
        return (tier.minAmount, tier.boostMultiplier, tier.lockPeriod);
    }
    
    function getUserStakeInfo(address _user) external view returns (
        uint256 amount,
        uint256 stakingTime,
        uint256 tierIndex,
        uint256 lockedUntil,
        bool canWithdraw,
        uint256 penalty
    ) {
        UserStake memory userStake = userStakes[_user];
        return (
            userStake.amount,
            userStake.stakingTime,
            userStake.tierIndex,
            userStake.lockedUntil,
            canWithdrawWithoutPenalty(_user),
            calculatePenalty(_user, userStake.amount)
        );
    }
}