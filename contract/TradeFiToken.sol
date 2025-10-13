// SPDX-License--Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TradeFiToken (TFT)
 * @dev The native ERC20 token for the TradeFi platform.
 * Used for governance voting and staking rewards.
 */
contract TradeFiToken is ERC20, Ownable {
    constructor() ERC20("TradeFi Token", "TFT") Ownable(msg.sender) {
        // Optionally mint an initial supply to the deployer/treasury
        _mint(msg.sender, 100000000 * (10**decimals()));
    }

    /**
     * @dev Creates new tokens. Can only be called by the contract owner.
     * This is useful for funding the rewards contract or for future distribution.
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}