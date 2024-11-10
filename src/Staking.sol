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
    error Staking__InsufficientBalance();
    error Staking__NotAdmin();

    // Type declarations
    struct User {
        uint256 amountToStake;
        uint256 duration;
        uint256 timeStaked;
    }

    // State variables
    CodeToken private immutable i_codeToken;
    address private immutable i_admin;
    mapping(address => User) private s_userStakeDetails;
    bool private stakingPaused;
    uint256 private apr;

    // Events
    event TokenStaked(address indexed user, uint256 amount, uint256 duration);
    event StakingResumed();
    event StakingPaused();
    event AprUpdated(uint256 newApr);

    // Constructor
    constructor(address _admin, address _codeToken) {
        i_admin = _admin;
        i_codeToken = CodeToken(_codeToken);
    }

    // Modifier to restrict access to only the admin
    modifier onlyAdmin() {
        if (msg.sender != i_admin) {
            revert Staking__NotAdmin();
        }
        _;
    }

    // Function to allow users to stake tokens
    function stake(
        uint256 amountToStake,
        uint256 duration
    ) public {
        address user = msg.sender;
        if (amountToStake > IERC20(i_codeToken).balanceOf(user)) {
            revert Staking__InsufficientBalance();
        }
        require(!stakingPaused, "Staking is currently paused");

        // Transfer tokens from the user to the contract
        IERC20(i_codeToken).transferFrom(user, address(this), amountToStake);

        // Update user's staking details
        s_userStakeDetails[user] = User({
            amountToStake: amountToStake,
            duration: duration,
            timeStaked: block.timestamp
        });

        emit TokenStaked(user, amountToStake, duration);
    }

    // Admin-only function to resume staking
    function resumeStaking() public onlyAdmin {
        stakingPaused = false;
        emit StakingResumed();
    }

    // Admin-only function to pause staking
    function pauseStaking() public onlyAdmin {
        stakingPaused = true;
        emit StakingPaused();
    }

    // Admin-only function to update APR
    function updateAPR(uint256 _newApr) public onlyAdmin {
        apr = _newApr;
        emit AprUpdated(_newApr);
    }
}
