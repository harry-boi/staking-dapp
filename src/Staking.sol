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
    error Staking__InsufficientBalance();

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

    //events
    event TokenStaked();

    //Functions
    constructor(address _admin, address _codeToken) {
        i_admin = _admin;
        i_codeToken = CodeToken(_codeToken);
    }

    function stake(
        address user,
        uint256 amountToStake,
        uint256 duration
    ) public {
        if (amountToStake > IERC20(i_codeToken).balanceOf(user)) {
            revert Staking__InsufficientBalance();
        }
    }
}
