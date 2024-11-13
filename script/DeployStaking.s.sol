// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {Staking} from "../src/Staking.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CodeToken} from "../src/CodeToken.sol";

contract DeployStaking is Script {
    address ct = 0xD207c672535b53496Ffff39cCE8D9fD2cf5352db; //contract address of token already deployed on base sepolia
    // CodeToken ct; //use for local setup
    Staking staking;
    address private constant ADMIN = 0xE38467773B31EA89d366e122E950148BBcBDc21A;

    function run() external returns (Staking, CodeToken, address) {
        vm.startBroadcast(ADMIN);
        //ct = new CodeToken(); //use for local setup
        staking = new Staking(ADMIN, address(ct));
        vm.stopBroadcast();
        return (staking, CodeToken(ct), ADMIN);
    }
}
