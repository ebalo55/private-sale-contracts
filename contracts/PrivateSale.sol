//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMelodity {
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

	function release(uint256 lock_id) external;

	function burn(uint256 amount) external;

	function balanceOf(address account) external returns(uint256);
}

contract PrivateSale is Ownable {
    AggregatorV3Interface internal priceFeed;
    IMelodity internal melodity;

    uint256 public maxRelease;
    uint256 public released;

    event Released(uint256 amount);
    event Bought(address account, uint256 amount);

	uint256 public alive_until = 1642118399;
    uint256 public ICO_END = 1648771199;
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
        melodity = IMelodity(0x13E971De9181eeF7A4aEAEAA67552A6a4cc54f43);

        maxRelease = 1 * 10**melodity.decimals();
        released = 1 * 10**(melodity.decimals() - 1); // 1 decimal position
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
		require(block.timestamp < alive_until, "Private sale elapsed");
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

	/**
     * Set a new max release amount, 18 decimals	
	 */
    function updateMaxRelease(uint256 _newMaxRelease) public onlyOwner {
        maxRelease = _newMaxRelease;
    }

	/**
     * Interact with the melodity token to redeem the self lock
     * and completely burn immediately.
     * All this is done in the same transaction.
     */
    function burnUnsold() public onlyOwner {
        require(
            block.timestamp >= alive_until,
            "Private sale is still live, cannot burn unsold"
        );
		
        melodity.release(0);
        melodity.burn(melodity.balanceOf(address(this)));
    }

	/**
     * Interact with the melodity token to create a self lock.
     */
    function createSelfLock() public onlyOwner {
        require(
            block.timestamp >= alive_until,
            "Private sale is still live, cannot burn unsold"
        );

        uint256 unsold = maxRelease - released;
        if (unsold > 0) {
            melodity.insertLock(address(this), unsold, 0);
            released = maxRelease;
        }
    }
}
