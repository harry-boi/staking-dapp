// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CodeToken} from "./CodeToken.sol";

/**
 * @title CodeToken Staking contract
 * @author Emmanuel Oludare & Dan Harry
 * @notice This contract allows users to stake,unstake CodeToken and earn rewards.
 */

contract Staking {
    //errors
    error Staking__InsufficientBalanceToStake();
    error Staking__NotEnoughStakingAmount();
    error Staking__NotEnoughStakingPeriod();
    error Staking__InsufficientBalance();
    error Staking__NotEnoughAmountStaked();
    error Staking__TokensLocked();

    // Type declarations
    struct User {
        uint256 totalAmountStaked;
        uint256 stakingDuration;
        uint256 stakingStartTime;
    }

    // State variables
    CodeToken private immutable i_codeToken;
    address private immutable i_admin;
    mapping(address => User) private s_userStakeDetails;
    uint256 private constant MINIMUM_STAKING_DURATION = 1 weeks;
    uint256 private constant WEEKLY_PERCENTAGE = 1; //1% per week

    //events
    event TokenStaked(address indexed user, uint256 amount, uint256 duration);

    //Functions
    constructor(address _admin, address _codeToken) {
        i_admin = _admin;
        i_codeToken = CodeToken(_codeToken);
    }

    function stake(uint256 amountToStake, uint256 duration) public {
        uint256 userBalance = IERC20(i_codeToken).balanceOf(msg.sender);

        if (amountToStake <= 0) {
            revert Staking__NotEnoughStakingAmount();
        }

        if (duration < MINIMUM_STAKING_DURATION) {
            revert Staking__NotEnoughStakingPeriod();
        }

        if (amountToStake > userBalance) {
            revert Staking__InsufficientBalanceToStake();
        }

        // Transfer tokens from the user to the contract
        IERC20(i_codeToken).transferFrom(
            msg.sender,
            address(this),
            amountToStake
        );

        // Retrieve the user's current stake details
        User storage userStake = s_userStakeDetails[msg.sender];

        // Check if this is an additional stake or the first one
        if (userStake.totalAmountStaked > 0) {
            // User has staked before; add to their existing stake
            userStake.totalAmountStaked += amountToStake;
            // Extend the staking duration
            userStake.stakingDuration += duration;
        } else {
            // This is the first stake for the user
            userStake.totalAmountStaked = amountToStake;
            userStake.stakingDuration = duration;
            userStake.stakingStartTime = block.timestamp;
        }

        emit TokenStaked(msg.sender, amountToStake, duration);
    }

    function unstake(uint256 amountToUnStake) public {
        if (
            amountToUnStake > s_userStakeDetails[msg.sender].totalAmountStaked
        ) {
            revert Staking__InsufficientBalance();
        }

        if (
            block.timestamp <
            s_userStakeDetails[msg.sender].stakingStartTime +
                MINIMUM_STAKING_DURATION
        ) {
            revert Staking__TokensLocked();
        }

        User storage userStake = s_userStakeDetails[msg.sender];
        userStake.totalAmountStaked -= amountToUnStake;

        IERC20(i_codeToken).transfer(msg.sender, amountToUnStake);
    }

    function calculateReward(address user) public view returns (uint256) {
        User storage userStake = s_userStakeDetails[user];
        uint256 weeklyRate = (WEEKLY_PERCENTAGE * userStake.totalAmountStaked) /
            100; //1% of total amount staked
        uint256 weeksSinceStaked = (block.timestamp -
            userStake.stakingStartTime) / MINIMUM_STAKING_DURATION;
        uint256 reward = weeklyRate * weeksSinceStaked;
        return reward;
    }

    function claimReward() public {
        if (s_userStakeDetails[msg.sender].totalAmountStaked <= 0) {
            revert Staking__NotEnoughAmountStaked();
        }
        uint256 reward = calculateReward(msg.sender);
        IERC20(i_codeToken).transfer(msg.sender, reward);
    }

    function getStakedBalance(address user) public view returns (uint256) {
        return s_userStakeDetails[user].totalAmountStaked;
    }

    function getRewardBalance(address user) public view returns (uint256) {
        uint256 reward = calculateReward(user);
        return reward;
    }
}
