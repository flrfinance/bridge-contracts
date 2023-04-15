// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/libraries/Multisig.sol";
import "../src/interfaces/IWrap.sol";
import "./utils/Constants.sol";

contract ConfigureMultisig is Script, Constants {
    //address constant wrap = APOTHEM;
    address constant wrap = COSTON;

    uint8 constant firstCommitteeAcceptanceQuorum = 1;
    uint8 constant secondCommitteeAcceptanceQuorum = 2;

    function run() external {
        vm.startBroadcast();
        Multisig.Config memory c = Multisig.Config(
            firstCommitteeAcceptanceQuorum,
            secondCommitteeAcceptanceQuorum
        );
        IWrap(wrap).configureMultisig(c);
        vm.stopBroadcast();
    }
}
