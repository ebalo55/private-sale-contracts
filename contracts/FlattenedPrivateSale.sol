// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// File @chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol@v0.2.2

interface AggregatorV3Interface {

  function decimals()
    external
    view
    returns (
      uint8
    );

  function description()
    external
    view
    returns (
      string memory
    );

  function version()
    external
    view
    returns (
      uint256
    );

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(
    uint80 _roundId
  )
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

}


// File @openzeppelin/contracts/utils/Context.sol@v4.4.0

// OpenZeppelin Contracts v4.4.0 (utils/Context.sol)

pragma solidity ^0.8.0;

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
}


// File @openzeppelin/contracts/access/Ownable.sol@v4.4.0

// OpenZeppelin Contracts v4.4.0 (access/Ownable.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
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


// File contracts/PrivateSale.sol

pragma solidity ^0.8.0;


interface MelodityLocks {
    /**
     * Lock the provided amount of MELD for "relativeReleaseTime" seconds starting from now
     * NOTE: This method is capped
     * NOTE: time definition in the locks is relative!
     */
    function insertLock(
        address account,
        uint256 amount,
        uint256 relativeReleaseTime
    ) external;

    function decimals() external returns (uint8);
}

contract PrivateSale is Ownable {
    AggregatorV3Interface internal priceFeed;
    MelodityLocks internal melodity;

    uint256 public maxRelease;
    uint256 public released;

    event Released(uint256 amount);
    event Bought(address account, uint256 amount);

    uint256 ICO_END = 1648771199;
    uint256 month = 2592000; // 60 * 60 * 24 * 30

    /**
     * Network: Binance Smart Chain (BSC)
     * Aggregator: BNB/USD
     * Address: 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE
     *
     * Melodity Bep20: 0x13E971De9181eeF7A4aEAEAA67552A6a4cc54f43
     */
    constructor() {
        priceFeed = AggregatorV3Interface(
            0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE
        );
        melodity = MelodityLocks(0x13E971De9181eeF7A4aEAEAA67552A6a4cc54f43);

        maxRelease = INSERT_MAX_RELEASE_HERE * 10**melodity.decimals();
        released = INSERT_ALREADY_RELEASED_AMOUNT_HERE * 10**(melodity.decimals() - 1); // 1 decimal position
    }

    /**
     * Returns the latest price and the update time
     */
    function getLatestPrice() public view returns (uint256, uint256) {
        (, int256 price, , uint256 timestamp, ) = priceFeed.latestRoundData();
        return (uint256(price), timestamp);
    }

    receive() external payable {
        require(
            msg.value >= 1 ether,
            "Private sale requires a minimum investment of 1 BNB"
        );
        require(released < maxRelease, "Private sale exhausted");
        buy(msg.sender, msg.value);
    }

    function buy(address account, uint256 bnb) private {
        (uint256 bnbValue, ) = getLatestPrice();

        // BNB has 18 decimals
        // realign the decimals of bnb and its price in USD
        bnbValue *= 10**(18 - priceFeed.decimals());

        // 0.025 $ per MELD => 1 $ = 1000 / 25 = 40 MELD
        uint256 rate = 40;
        uint256 meldToBuy = (bnb * bnbValue * rate) / 10**18;
        uint256 bnbDifference;

        if (meldToBuy + released > maxRelease) {
            // compute the difference to send a refund
            uint256 difference = meldToBuy + released - maxRelease;

            // get maximum amount of buyable meld
            uint256 realMeldToBuy = meldToBuy - difference;

            bnbDifference = (difference * 10**18) / rate / bnbValue;

            meldToBuy = realMeldToBuy;
        }

        // update the realeased amount asap
        released += meldToBuy;

        // immediately release the 10% of the bought amount
        uint256 immediatelyReleased = meldToBuy / 10; // * 10 / 100 = / 10
        // 15% released after 6 months
        uint256 m6Release = (meldToBuy * 15) / 100;
        // 25% released after 6 months from ico end
        uint256 m6ICORelease = (meldToBuy * 25) / 100;
        // 25% released after 12 months from ico end
        uint256 m12ICORelease = (meldToBuy * 25) / 100;
        // 25% released after 18 months from ico end
        uint256 m18ICORelease = meldToBuy -
            (immediatelyReleased + m6Release + m6ICORelease + m12ICORelease);

        melodity.insertLock(account, immediatelyReleased, 0);
        melodity.insertLock(account, m6Release, month * 6);
        melodity.insertLock(
            account,
            m6ICORelease,
            ICO_END - block.timestamp + month * 6
        );
        melodity.insertLock(
            account,
            m12ICORelease,
            ICO_END - block.timestamp + month * 12
        );
        melodity.insertLock(
            account,
            m18ICORelease,
            ICO_END - block.timestamp + month * 18
        );

        // refund needed
        if (bnbDifference > 0) {
            // refund the difference
            payable(account).transfer(bnbDifference);
        }

        emit Bought(account, meldToBuy);
    }

    /**
     * Release the funds on this smart contract to the multisig wallet
     */
    function release() public onlyOwner {
        // company wallet: 0x01Af10f1343C05855955418bb99302A6CF71aCB8
        uint256 balance = address(this).balance;
        payable(0x01Af10f1343C05855955418bb99302A6CF71aCB8).transfer(balance);

        emit Released(balance);
    }

    function updateMaxRelease(uint256 _newMaxRelease) public onlyOwner {
        maxRelease = _newMaxRelease;
    }
}
