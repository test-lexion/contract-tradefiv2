// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AssetVault.sol";

/**
 * @title SpotExchange
 * @dev Handles the logic for executing spot trades.
 * It is authorized to move funds within the AssetVault.
 */
contract SpotExchange {
    AssetVault public assetVault;
    address public feeWallet; // Wallet to collect trading fees

    // tokenA -> tokenB -> price (e.g., WETH -> USDC -> 3500)
    mapping(address => mapping(address => uint256)) public prices; 
    uint256 public feeBps = 10; // 0.10% fee (10 basis points)

    event TradeExecuted(
        address indexed user,
        address indexed tokenFrom,
        address indexed tokenTo,
        uint256 amountFrom,
        uint256 amountTo
    );
    event PriceUpdated(address indexed tokenA, address indexed tokenB, uint256 newPrice);

    constructor(address _vaultAddress, address _feeWallet) {
        assetVault = AssetVault(_vaultAddress);
        feeWallet = _feeWallet;
    }

    /**
     * @dev Executes a spot trade.
     * @param _tokenFrom The token the user is selling.
     * @param _tokenTo The token the user is buying.
     * @param _amountFrom The amount of tokenFrom the user wants to sell.
     */
    function executeTrade(address _tokenFrom, address _tokenTo, uint256 _amountFrom) external {
        require(_amountFrom > 0, "Amount must be > 0");
        uint256 price = prices[_tokenFrom][_tokenTo];
        require(price > 0, "Price not set for this pair");

        // Calculate the amount of tokenTo the user will receive, before fees
        // Note: Assumes both tokens have 18 decimals for simplicity.
        // A production version MUST handle different decimal places.
        uint256 amountTo = (_amountFrom * price) / 1e18;

        // Calculate and deduct the fee
        uint256 fee = (amountTo * feeBps) / 10000;
        uint256 amountToAfterFee = amountTo - fee;

        // Use the vault to move funds
        // 1. Move tokenFrom from user to the feeWallet (representing the protocol)
        assetVault.internalTransfer(_tokenFrom, msg.sender, feeWallet, _amountFrom);

        // 2. Move tokenTo from the feeWallet (protocol liquidity) to the user
        assetVault.internalTransfer(_tokenTo, feeWallet, msg.sender, amountToAfterFee);

        emit TradeExecuted(msg.sender, _tokenFrom, _tokenTo, _amountFrom, amountToAfterFee);
    }

    // --- Admin Functions ---
    // In a real DApp, the owner would be a Governance contract
    function setPrice(address _tokenA, address _tokenB, uint256 _price) external {
        // In production, this would be restricted (e.g., onlyOwner)
        prices[_tokenA][_tokenB] = _price;
        // Set inverse price
        prices[_tokenB][_tokenA] = (1e18 * 1e18) / _price;
        emit PriceUpdated(_tokenA, _tokenB, _price);
    }
}