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

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title CodeToken (ERC20 token) contract
 * @author Emmanuel Oludare & Dan Harry
 * @notice This contract creates an erc20 token that the fauce contract will dispense to users.
 */

contract CodeToken is ERC20 {
    constructor() ERC20("CodeToken", "CT") {
        uint256 initialSupply = 1_000_000_000 * 10 ** decimals();
        _mint(msg.sender, initialSupply);
    }
}
