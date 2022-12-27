// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/WrapDepositRedeem.sol";
import "../src/libraries/Multisig.sol";

contract DeployWrapDepositRedeem is Script {
    // TODO: fix the numbers
    uint8 constant firstCommitteeAcceptanceQuorum = 1;
    uint8 constant secondCommitteeAcceptanceQuorum = 1;
    uint8 constant validatorFeeBPS = 50;

    function run() external {
        vm.startBroadcast();
        Multisig.Config memory c = Multisig.Config(
            firstCommitteeAcceptanceQuorum,
            secondCommitteeAcceptanceQuorum
        );
        new WrapDepositRedeem(c, validatorFeeBPS);
        vm.stopBroadcast();
    }
}
