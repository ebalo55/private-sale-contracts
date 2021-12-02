//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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

contract TestablePrivateSale is Ownable {
    uint256 public maxRelease;
    uint256 public released;

    event Released(uint256 amount);
    event Bought(address account, uint256 amount);

    uint256 public ICO_END = 1648771199;
    uint256 month = 2592000; // 60 * 60 * 24 * 30

    bool log = false;

    /**
     * Network: Binance Smart Chain (BSC)
     * Aggregator: BNB/USD
     * Address: 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE
     *
     * Melodity Bep20: 0x13E971De9181eeF7A4aEAEAA67552A6a4cc54f43
     */
    constructor() {
        maxRelease = 50_000_000 * 10**18;
        released = 49970000 * 10**18; // no decimal positions
    }

    /**
     * Returns the latest price and the update time
     */
    function getLatestPrice() public view returns (uint256, uint256) {
        int256 price = 62322000000; // 623.22 $
        uint256 timestamp = block.timestamp;
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
        if (log) {
            console.log("BNB value [pre parse]:", bnbValue);
        }
        bnbValue *= 10**(18 - 8);
        if (log) {
            console.log("BNB value [parsed]:", bnbValue);
        }

        // 0.025 $ per MELD => 1 $ = 1000 / 25 = 40 MELD
        uint256 rate = 40;
        uint256 meldToBuy = (bnb * bnbValue * rate) / 10**18;
        uint256 bnbDifference;
        if (log) {
            console.log("$MELD change rate:", rate);
            console.log("$MELD to buy:", meldToBuy);
        }

        if (meldToBuy + released > maxRelease) {
            // compute the difference to send a refund
            uint256 difference = meldToBuy + released - maxRelease;
            if (log) {
                console.log("difference:", difference);
            }

            // get maximum amount of buyable meld
            uint256 realMeldToBuy = meldToBuy - difference;
            if (log) {
                console.log("realMeldToBuy:", realMeldToBuy);
            }

            bnbDifference = (difference * 10**18) / rate / bnbValue;
            if (log) {
                console.log("bnbDifference:", bnbDifference);
            }

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

        if (log) {
            console.log("----------------------------");
            console.log("calling melodity.insertLock:");
            console.log("    amount: ", immediatelyReleased);
            console.log("    release-time: ", block.timestamp + 0);
            console.log("----------------------------");
            console.log("calling melodity.insertLock:");
            console.log("    amount: ", m6Release);
            console.log("    release-time: ", block.timestamp + month * 6);
            console.log("----------------------------");
            console.log("calling melodity.insertLock:");
            console.log("    amount: ", m6ICORelease);
            console.log(
                "    release-time: ",
                block.timestamp + ICO_END - block.timestamp + month * 6
            );
            console.log("----------------------------");
            console.log("calling melodity.insertLock:");
            console.log("    amount: ", m12ICORelease);
            console.log(
                "    release-time: ",
                block.timestamp + ICO_END - block.timestamp + month * 12
            );
            console.log("----------------------------");
            console.log("calling melodity.insertLock:");
            console.log("    amount: ", m18ICORelease);
            console.log(
                "    release-time: ",
                block.timestamp + ICO_END - block.timestamp + month * 18
            );
            console.log("----------------------------");
        }

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
