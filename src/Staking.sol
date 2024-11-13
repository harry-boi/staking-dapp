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
// view & pure function

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CodeToken} from "./CodeToken.sol";

/**
 * @title CodeToken Staking contract
 * @notice This contract allows users to stake, unstake CodeToken, and earn rewards.
 */
contract Staking {
    // Errors
    error Staking__NotAdmin();
    error Staking__InsufficientBalanceToStake();
    error Staking__NotEnoughStakingAmount();
    error Staking__NotEnoughStakingPeriod();
    error Staking__InsufficientBalance();
    error Staking__NotEnoughAmountStaked();
    error Staking__TokensLocked();
    error Staking__StakeIndexInvalid();

    // Type declarations
    struct UserStake {
        uint256 amountStaked;
        uint256 stakingDuration;
        uint256 stakingStartTime;
        uint256 apr;
        uint256 stakeRewards;
    }

    // State variables
    CodeToken private immutable i_codeToken;
    address private immutable i_admin;
    mapping(address => UserStake[]) private s_userStakeDetails;
    mapping(uint256 => uint256) private s_durationToApr;
    bool private stakingPaused;
    uint256 private constant MINIMUM_STAKE_DURATION = 1 weeks;
    uint256 private s_totalTokensStaked;

    // Events
    event TokenStaked(address indexed user, uint256 amount, uint256 duration);
    event StakingResumed();
    event StakingPaused();
    event AprUpdated(uint256 newApr);

    // Modifier to restrict access to only the admin
    modifier onlyAdmin() {
        if (msg.sender != i_admin) {
            revert Staking__NotAdmin();
        }
        _;
    }

    // Constructor
    constructor(address _admin, address _codeToken) {
        i_admin = _admin;
        i_codeToken = CodeToken(_codeToken);

        //Initializing default APY
        s_durationToApr[1 weeks] = 3; //offers a 3% APR to users after 1 week
        s_durationToApr[4 weeks] = 12; //offers a 12% APR to users after 1 month
    }

    // Function to allow users to stake tokens
    function stake(uint256 amountToStake, uint256 duration) public {
        require(!stakingPaused, "Staking is currently paused");

        uint256 userBalance = IERC20(i_codeToken).balanceOf(msg.sender);

        if (amountToStake > userBalance) {
            revert Staking__InsufficientBalanceToStake();
        }

        if (amountToStake <= 0) {
            revert Staking__NotEnoughStakingAmount();
        }

        if (duration < MINIMUM_STAKE_DURATION) {
            revert Staking__NotEnoughStakingPeriod();
        }

        // Transfer tokens from the user to the contract
        IERC20(i_codeToken).transferFrom(
            msg.sender,
            address(this),
            amountToStake
        );

        //set the user's new stake details
        UserStake memory newUserStake = UserStake({
            amountStaked: amountToStake,
            stakingDuration: duration,
            stakingStartTime: block.timestamp,
            apr: s_durationToApr[duration],
            stakeRewards: calculateReward(amountToStake, duration)
        });
        s_totalTokensStaked += amountToStake;
        s_userStakeDetails[msg.sender].push(newUserStake);

        emit TokenStaked(msg.sender, amountToStake, duration);
    }

    // Admin-only function to resume staking
    function resumeStaking() public onlyAdmin {
        require(stakingPaused, "Staking is currently active");
        stakingPaused = false;
        emit StakingResumed();
    }

    // Admin-only function to pause staking
    function pauseStaking() public onlyAdmin {
        require(!stakingPaused, "Staking is currently paused");
        stakingPaused = true;
        emit StakingPaused();
    }

    // Admin-only function to update APR
    function updateAPR(uint256 _duration, uint256 _newApr) public onlyAdmin {
        s_durationToApr[_duration] = _newApr;
        emit AprUpdated(_newApr);
    }

    function claimReward(uint256 index) public {
        if (
            block.timestamp <
            getStakeStartTime(msg.sender, index) +
                getStakeDuration(msg.sender, index)
        ) {
            revert Staking__TokensLocked();
        }

        if (getStakedBalance(msg.sender, index) <= 0) {
            revert Staking__NotEnoughAmountStaked();
        }

        if (index > s_userStakeDetails[msg.sender].length) {
            revert Staking__StakeIndexInvalid();
        }

        UserStake storage userStake = s_userStakeDetails[msg.sender][index];
        s_totalTokensStaked -= userStake.amountStaked;
        uint256 rewardAndStake = userStake.amountStaked +
            userStake.stakeRewards;
        userStake.amountStaked = 0;
        userStake.stakeRewards = 0;

        IERC20(i_codeToken).transfer(msg.sender, rewardAndStake);
    }

    function calculateReward(
        uint256 amountStaked,
        uint256 duration
    ) public view returns (uint256) {
        uint256 durationInWeeks = duration / 1 weeks;
        uint256 weeklyRate = (getAprPercentage(duration) * amountStaked) / 100; //% of total amount staked
        uint256 reward = weeklyRate * durationInWeeks;
        return reward;
    }

    function getStakedBalance(
        address user,
        uint256 index
    ) public view returns (uint256) {
        if (index > s_userStakeDetails[user].length) {
            revert Staking__StakeIndexInvalid();
        }
        return s_userStakeDetails[user][index].amountStaked;
    }

    function getStakeDuration(
        address user,
        uint256 index
    ) public view returns (uint256) {
        if (index > s_userStakeDetails[user].length) {
            revert Staking__StakeIndexInvalid();
        }
        return s_userStakeDetails[user][index].stakingDuration;
    }

    function getStakeStartTime(
        address user,
        uint256 index
    ) public view returns (uint256) {
        if (index > s_userStakeDetails[user].length) {
            revert Staking__StakeIndexInvalid();
        }
        return s_userStakeDetails[user][index].stakingStartTime;
    }

    function getRewardBalance(
        address user,
        uint256 index
    ) public view returns (uint256) {
        if (index > s_userStakeDetails[user].length) {
            revert Staking__StakeIndexInvalid();
        }
        return s_userStakeDetails[user][index].stakeRewards;
    }

    function getUserStakeAprPercentage(
        address user,
        uint256 index
    ) public view returns (uint256) {
        if (index > s_userStakeDetails[user].length) {
            revert Staking__StakeIndexInvalid();
        }
        return s_userStakeDetails[user][index].apr;
    }

    function getAprPercentage(uint256 _duration) public view returns (uint256) {
        return s_durationToApr[_duration];
    }

    function checkTimeLeftToUnlock(
        address user,
        uint256 index
    ) public view returns (uint256) {
        if (index > s_userStakeDetails[user].length) {
            revert Staking__StakeIndexInvalid();
        }
        uint256 totalDuration = getStakeStartTime(user, index) +
            getStakeDuration(user, index);
        if (block.timestamp < totalDuration) {
            return totalDuration - block.timestamp;
        } else {
            return 0;
        }
    }

    function isStakingPaused() public view returns (bool) {
        return stakingPaused;
    }

    function getTotalTokensStaked() public view returns (uint256) {
        return s_totalTokensStaked;
    }

    function getCtToken() public view returns (CodeToken) {
        return i_codeToken;
    }

    function getAdmin() public view returns (address) {
        return i_admin;
    }
}
