
// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/IERC20.sol)

pragma solidity >=0.4.16;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: @openzeppelin/contracts/utils/ReentrancyGuard.sol


// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// File: contract/AssetVault.sol


pragma solidity ^0.8.20;




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
// File: contract/SpotExchange.sol


pragma solidity ^0.8.20;


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