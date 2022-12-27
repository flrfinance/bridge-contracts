// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/interfaces/IWrap.sol";

contract Deposit is Script {
    address constant wrap = 0x9550c9651b681Ce9FE1f3D8c416F785e6350274c;
    address constant token = 0xE99500AB4A413164DA49Af83B9824749059b46ce;
    address constant to = 0xECaEA3cd833Ad3AF575229280D91dEfb131130e9;
    uint256 constant amount = 1e18;

    function run() external {
        vm.startBroadcast(0x4C5F0f90a2D4b518aFba11E22AC9b8F6B031d204);
        IERC20(token).approve(wrap, amount);
        uint256 index = IWrap(wrap).deposit(token, amount, to);
        console.log(index);
        vm.stopBroadcast();
    }
}
