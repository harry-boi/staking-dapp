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
    error Staking__StakeDurationNotComplete();

    // Type declarations
    struct User {
        uint256 totalAmountStaked;
        uint256 stakingDuration;
        uint256 stakingStartTime;
        uint256 apy;
    }

    // State variables
    CodeToken private immutable i_codeToken;
    address private immutable i_admin;
    mapping(address => User) private s_userStakeDetails;
    mapping(uint256 => uint256) public s_durationToApy;
    bool private stakingPaused;
    uint256 private aprWeeklyPercentage = 1; //1% per week
    uint256 private constant MINIMUM_STAKING_DURATION = 1 weeks;

    // Events
    event TokenStaked(address indexed user, uint256 amount, uint256 duration);
    event StakingResumed();
    event StakingPaused();
    event AprUpdated(uint256 newApr);

    // Constructor
    constructor(address _admin, address _codeToken) {
        i_admin = _admin;
        i_codeToken = CodeToken(_codeToken);

        //Initializing default APY
        s_durationToApy[1 weeks] = 5; //offers a 5% APY to users after 1 week
        s_durationToApy[1 weeks] = 15; //offers a 15% APY to users after 1 month
    }

    // Modifier to restrict access to only the admin
    modifier onlyAdmin() {
        if (msg.sender != i_admin) {
            revert Staking__NotAdmin();
        }
        _;
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

        if (duration < MINIMUM_STAKING_DURATION) {
            revert Staking__NotEnoughStakingPeriod();
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
            userStake.apy = s_durationToApy[duration];
        } else {
            // This is the first stake for the user
            userStake.totalAmountStaked = amountToStake;
            userStake.stakingDuration = duration;
            userStake.stakingStartTime = block.timestamp;
            userStake.apy = s_durationToApy[duration];
        }

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
    function updateAPR(uint256 _newApr) public onlyAdmin {
        aprWeeklyPercentage = _newApr;
        emit AprUpdated(_newApr);
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

    function claimReward() public {
        User storage userStake = s_userStakeDetails[msg.sender];
        if (userStake.totalAmountStaked <= 0) {
            revert Staking__NotEnoughAmountStaked();
        }

        if (
            block.timestamp <
            userStake.stakingStartTime + userStake.stakingDuration
        ) {
            revert Staking__StakeDurationNotComplete();
        }
        uint256 reward = calculateReward(msg.sender);
        IERC20(i_codeToken).transfer(msg.sender, reward);
    }

    function calculateReward(address user) public view returns (uint256) {
        uint256 weeklyRate = (aprWeeklyPercentage * getStakedBalance(user)) /
            100; //% of total amount staked
        uint256 weeksSinceStaked = (block.timestamp - getStakeStartTime(user)) /
            MINIMUM_STAKING_DURATION;
        uint256 reward = weeklyRate * weeksSinceStaked;
        return reward;
    }

    function getStakedBalance(address user) public view returns (uint256) {
        return s_userStakeDetails[user].totalAmountStaked;
    }

    function getStakeDuration(address user) public view returns (uint256) {
        return s_userStakeDetails[user].stakingDuration;
    }

    function getStakeStartTime(address user) public view returns (uint256) {
        return s_userStakeDetails[user].stakingStartTime;
    }

    function getRewardBalance(address user) public view returns (uint256) {
        uint256 reward = calculateReward(user);
        return reward;
    }

    function getAprWeeklyPercentage() public view returns (uint256) {
        return aprWeeklyPercentage;
    }

    function checkTimeLeftToUnlock(address user) public view returns (uint256) {
        uint256 totalDuration = getStakeStartTime(user) +
            getStakeDuration(user);
        if (block.timestamp < totalDuration) {
            return totalDuration - block.timestamp;
        } else {
            return 0;
        }
    }

    function isStakingPaused() public returns(bool){
        return stakingPaused;
    }
}
