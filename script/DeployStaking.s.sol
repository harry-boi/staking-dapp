// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {Staking} from "../src/Staking.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CodeToken} from "../src/CodeToken.sol";

contract DeployStaking is Script {
    //address ct = 0xD207c672535b53496Ffff39cCE8D9fD2cf5352db; //contract address of token already deployed on base sepolia
    CodeToken ct;
    Staking staking;
    address private constant ADMIN = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function run() external returns (Staking, CodeToken, address) {
        vm.startBroadcast(ADMIN);
        ct = new CodeToken();
        staking = new Staking(ADMIN, address(ct));
        vm.stopBroadcast();
        return (staking, ct, ADMIN);
    }
}
