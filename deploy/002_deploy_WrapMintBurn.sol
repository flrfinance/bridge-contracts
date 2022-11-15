// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/WrapMintBurn.sol";
import "../src/libraries/Multisig.sol";

contract DeployWrapMintBurn is Script {
    // TODO: fix the numbers
    uint8 constant firstCommitteeAcceptanceQuorum = 1;
    uint8 constant secondCommitteeAcceptanceQuorum = 1;
    uint8 constant validatorFeeBPS = 0;
    uint8 constant protocolFeeBPS = 0;

    function run() external {
        vm.startBroadcast();
        Multisig.Config memory c = Multisig.Config(
            firstCommitteeAcceptanceQuorum,
            secondCommitteeAcceptanceQuorum
        );
        new WrapMintBurn(c, protocolFeeBPS, validatorFeeBPS);
        vm.stopBroadcast();
    }
}
