// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/interfaces/IWrap.sol";

contract RemoveValidator is Script {
    address constant wrap = APOTHEM;
    //address constant wrap = COSTON;

    address constant validator = 0xebAa49C421A6158f280A04a0DEd08189110Cdf1F;

    function run() external {
        vm.startBroadcast();
        IWrap(wrap).removeValidator(validator);
        vm.stopBroadcast();
    }
}
