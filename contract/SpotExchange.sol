// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AssetVault.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title SpotExchange
 * @dev Handles the logic for executing spot trades.
 * It is authorized to move funds within the AssetVault.
 */
contract SpotExchange is Ownable, ReentrancyGuard {
    AssetVault public assetVault;
    address public feeWallet; // Wallet to collect trading fees

    // tokenA -> tokenB -> price (e.g., WETH -> USDC -> 3500)
    mapping(address => mapping(address => uint256)) public prices; 
    uint256 public feeBps = 10; // 0.10% fee (10 basis points)
    
    // Authorized price updaters (oracles, admin addresses)
    mapping(address => bool) public authorizedPriceUpdaters;
    
    // Slippage protection
    uint256 public maxSlippageBps = 500; // 5% maximum slippage
    
    // Trading pause mechanism
    bool public tradingPaused = false;

    event TradeExecuted(
        address indexed user,
        address indexed tokenFrom,
        address indexed tokenTo,
        uint256 amountFrom,
        uint256 amountTo
    );
    event PriceUpdated(address indexed tokenA, address indexed tokenB, uint256 newPrice);
    event PriceUpdaterChanged(address indexed updater, bool authorized);
    event TradingPauseChanged(bool paused);
    event SlippageProtectionChanged(uint256 newMaxSlippageBps);

    modifier onlyAuthorizedPriceUpdater() {
        require(authorizedPriceUpdaters[msg.sender] || msg.sender == owner(), "Not authorized to update prices");
        _;
    }
    
    modifier whenTradingNotPaused() {
        require(!tradingPaused, "Trading is paused");
        _;
    }

    constructor(address _vaultAddress, address _feeWallet) Ownable(msg.sender) {
        assetVault = AssetVault(_vaultAddress);
        feeWallet = _feeWallet;
        // Owner is authorized by default
        authorizedPriceUpdaters[msg.sender] = true;
    }

    /**
     * @dev Executes a spot trade with slippage protection.
     * @param _tokenFrom The token the user is selling.
     * @param _tokenTo The token the user is buying.
     * @param _amountFrom The amount of tokenFrom the user wants to sell.
     * @param _minAmountTo Minimum amount of tokenTo expected (slippage protection).
     */
    function executeTrade(
        address _tokenFrom, 
        address _tokenTo, 
        uint256 _amountFrom, 
        uint256 _minAmountTo
    ) external nonReentrant whenTradingNotPaused {
        require(_amountFrom > 0, "Amount must be > 0");
        uint256 price = prices[_tokenFrom][_tokenTo];
        require(price > 0, "Price not set for this pair");

        // Get token decimals for proper calculation
        uint8 fromDecimals = IERC20Metadata(_tokenFrom).decimals();
        uint8 toDecimals = IERC20Metadata(_tokenTo).decimals();

        // Calculate the amount of tokenTo the user will receive, before fees
        // Normalize for different decimal places
        uint256 amountTo = (_amountFrom * price * (10**toDecimals)) / (1e18 * (10**fromDecimals));

        // Calculate and deduct the fee
        uint256 fee = (amountTo * feeBps) / 10000;
        uint256 amountToAfterFee = amountTo - fee;
        
        // Slippage protection
        require(amountToAfterFee >= _minAmountTo, "Slippage too high");

        // Use the vault to move funds
        // 1. Move tokenFrom from user to the feeWallet (representing the protocol)
        assetVault.internalTransfer(_tokenFrom, msg.sender, feeWallet, _amountFrom);

        // 2. Move tokenTo from the feeWallet (protocol liquidity) to the user
        assetVault.internalTransfer(_tokenTo, feeWallet, msg.sender, amountToAfterFee);

        emit TradeExecuted(msg.sender, _tokenFrom, _tokenTo, _amountFrom, amountToAfterFee);
    }
    
    /**
     * @dev Get quote for a trade (view function)
     */
    function getQuote(address _tokenFrom, address _tokenTo, uint256 _amountFrom) 
        external view returns (uint256 amountTo, uint256 fee, uint256 amountToAfterFee) {
        require(_amountFrom > 0, "Amount must be > 0");
        uint256 price = prices[_tokenFrom][_tokenTo];
        require(price > 0, "Price not set for this pair");

        // Get token decimals for proper calculation
        uint8 fromDecimals = IERC20Metadata(_tokenFrom).decimals();
        uint8 toDecimals = IERC20Metadata(_tokenTo).decimals();

        // Calculate amounts
        amountTo = (_amountFrom * price * (10**toDecimals)) / (1e18 * (10**fromDecimals));
        fee = (amountTo * feeBps) / 10000;
        amountToAfterFee = amountTo - fee;
    }

    // --- Admin Functions ---
    /**
     * @dev Sets price for a trading pair. Only authorized updaters can call this.
     * @param _tokenA First token in the pair
     * @param _tokenB Second token in the pair  
     * @param _price Price of tokenA in terms of tokenB (scaled by 1e18)
     */
    function setPrice(address _tokenA, address _tokenB, uint256 _price) external onlyAuthorizedPriceUpdater {
        require(_price > 0, "Price must be greater than 0");
        prices[_tokenA][_tokenB] = _price;
        // Set inverse price
        prices[_tokenB][_tokenA] = (1e18 * 1e18) / _price;
        emit PriceUpdated(_tokenA, _tokenB, _price);
    }
    
    /**
     * @dev Authorize or deauthorize a price updater
     */
    function setPriceUpdater(address _updater, bool _authorized) external onlyOwner {
        authorizedPriceUpdaters[_updater] = _authorized;
        emit PriceUpdaterChanged(_updater, _authorized);
    }
    
    /**
     * @dev Pause or unpause trading
     */
    function setTradingPaused(bool _paused) external onlyOwner {
        tradingPaused = _paused;
        emit TradingPauseChanged(_paused);
    }
    
    /**
     * @dev Update trading fee
     */
    function setTradingFee(uint256 _newFeeBps) external onlyOwner {
        require(_newFeeBps <= 1000, "Fee cannot exceed 10%"); // Max 10% fee
        feeBps = _newFeeBps;
    }
    
    /**
     * @dev Update fee wallet
     */
    function setFeeWallet(address _newFeeWallet) external onlyOwner {
        require(_newFeeWallet != address(0), "Invalid fee wallet");
        feeWallet = _newFeeWallet;
    }
    
    /**
     * @dev Update maximum allowed slippage
     */
    function setMaxSlippage(uint256 _maxSlippageBps) external onlyOwner {
        require(_maxSlippageBps <= 2000, "Max slippage cannot exceed 20%");
        maxSlippageBps = _maxSlippageBps;
        emit SlippageProtectionChanged(_maxSlippageBps);
    }
}