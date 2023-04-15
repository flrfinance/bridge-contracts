// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "./utils/Constants.sol";
import {
    IAccessControl
} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract AddAdmin is Script, Constants {
    //address constant wrap = APOTHEM;
    address constant wrap = COSTON;

    //address constant newOwner = APOTHEM_MULTISIG; // in APOTHEM
    address constant newOwner = COSTON_MULTISIG; // in COSTON

    function run() external {
        vm.startBroadcast();
        IAccessControl(wrap).grantRole(0x0, newOwner);
        vm.stopBroadcast();
    }
}
