// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/interfaces/IWrap.sol";

contract AddValidator is Script {
    address constant wrap = 0x9550c9651b681Ce9FE1f3D8c416F785e6350274c;
    address constant validator = 0xBb0d20CC598E4d34A7eF50d4B55cd43850048c23;
    bool isFirstCommittee = true;

    function run() external {
        vm.startBroadcast();
        IWrap(wrap).addValidator(validator, isFirstCommittee);
        vm.stopBroadcast();
    }
}
