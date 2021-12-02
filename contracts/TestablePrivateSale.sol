//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
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

    function balanceOf(address account) external returns (uint256);
}

contract TestablePrivateSale is Ownable {
    IMelodity internal melodity;

    uint256 public maxRelease;
    uint256 public released;

    event Released(uint256 amount);
    event Bought(address account, uint256 amount);

    uint256 public alive_until;
    uint256 public ICO_END = 1648771199;
    uint256 month = 2592000; // 60 * 60 * 24 * 30

    bool log = false;

    struct referral {
        bytes32 code;
        uint256 percentage;
        uint8 decimals;
        uint256 startingTime;
        uint256 endingTime;
    }

    referral[] private referralCodes;

    /**
     * Network: Binance Smart Chain (BSC)
     * Aggregator: BNB/USD
     * Address: 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE
     *
     * Melodity Bep20: 0x13E971De9181eeF7A4aEAEAA67552A6a4cc54f43
     */
    constructor(uint256 _alive_until, address _melodity) {
        maxRelease = 50_000_000 * 10**18;
        released = 49970000 * 10**18; // no decimal positions
        alive_until = _alive_until;
        melodity = IMelodity(_melodity);
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
        buy("");
    }

    /**
     * Check a referral code using its raw string representation.
     * This method returns a tuple as follow:
     * (
     *		bonus_percentage,
     *		decimal_positions
     * )
     */
    function getReferral(string memory ref)
        private
        view
        returns (uint256, uint256)
    {
		if(log) {
			console.log("referralCodes.length:", referralCodes.length);
		}
        // check that referral is not empty
        if (referralCodes.length > 0) {
            // loop through referrals
            for (uint256 i; i < referralCodes.length; i++) {
                // hash the referral code to securely check it
                bytes32 h = keccak256(abi.encodePacked(ref));

                if (referralCodes[i].code == h) {
                    // cache the current timestamp
                    uint256 _now = block.timestamp;

                    // check if referral is valid, if it is not break the loop and return the default value
                    if (
                        _now >= referralCodes[i].startingTime &&
                        _now <= referralCodes[i].endingTime
                    ) {
                        return (
                            referralCodes[i].percentage,
                            referralCodes[i].decimals
                        );
                    }
                    break;
                }
            }
        }
        // no referral found, bonus is 0
        return (0, 0);
    }

    /**
     * Add a new referral to the list of available ones
     */
    function addReferral(
        string memory code,
        uint256 percentage,
        uint8 decimals,
        uint256 startingTime,
        uint256 endingTime
    ) public onlyOwner {
		if(log) { console.log("code:", code); }
        referralCodes.push(
            referral({
                code: keccak256(abi.encodePacked(code)),
                percentage: percentage,
                decimals: decimals,
                startingTime: startingTime,
                endingTime: endingTime
            })
        );
    }

    function buy(
        string memory ref
    ) public payable {
        require(
            msg.value >= 1 ether,
            "Private sale requires a minimum investment of 1 BNB"
        );
        require(released < maxRelease, "Private sale exhausted");
        require(block.timestamp < alive_until, "Private sale elapsed");

        (uint256 bnbValue, ) = getLatestPrice();
        (uint256 refPercentage, uint256 refDecimals) = getReferral(ref);
		if (log) {
			console.log("ref:", ref);
            console.log("refPercentage:", refPercentage);
            console.log("refDecimals:", refDecimals);
        }

		uint256 bnb = msg.value;
		address account = msg.sender;

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

		if(refPercentage > 0) {
			if(log) { console.log("meldToBuy (refPercentage > 0) [before computation]:", meldToBuy); }
			meldToBuy = meldToBuy + meldToBuy * refPercentage / 10 ** refDecimals;
			if(log) { console.log("meldToBuy (refPercentage > 0) [after computation]:", meldToBuy); }
		}

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
        if (log) {
            console.log("released:", released);
        }
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
        if (log) {
            console.log("maxRelease:", maxRelease);
            console.log("released:", released);
        }

        uint256 unsold = maxRelease - released;
        if (unsold > 0) {
            melodity.insertLock(address(this), unsold, 0);
            released = maxRelease;
        }
    }
}
