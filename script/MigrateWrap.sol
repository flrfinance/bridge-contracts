// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { WrapMintBurn } from "../src/WrapMintBurn.sol";
import { WrapDepositRedeem } from "../src/WrapDepositRedeem.sol";

contract MigrateWrap is Script {
    WrapMintBurn constant oldWrapMintBurn =
        WrapMintBurn(0x9550c9651b681Ce9FE1f3D8c416F785e6350274c);
    WrapMintBurn constant newWrapMintBurn =
        WrapMintBurn(0xE99500AB4A413164DA49Af83B9824749059b46ce);

    WrapDepositRedeem constant oldWrapDepositRedeem =
        WrapDepositRedeem(0x9550c9651b681Ce9FE1f3D8c416F785e6350274c);
    WrapDepositRedeem constant newWrapDepositRedeem =
        WrapDepositRedeem(0xE99500AB4A413164DA49Af83B9824749059b46ce);

    function run() external {
        uint256 sourceForkId = vm.createSelectFork(vm.rpcUrl("source"));
        require(
            oldWrapDepositRedeem.paused(),
            "Old WrapDepositRedeem contract should be paused"
        );
        require(
            oldWrapDepositRedeem.migratedContract() == address(0),
            "Old WrapDepositRedeem contract has already been migrated"
        );

        uint256 targetForkId = vm.createSelectFork(vm.rpcUrl("target"));
        require(
            oldWrapMintBurn.paused(),
            "Old WrapMintBurn contract should be paused"
        );
        require(
            oldWrapMintBurn.migratedContract() == address(0),
            "Old WrapMintBurn contract has already been migrated"
        );

        vm.selectFork(sourceForkId);
        oldWrapDepositRedeem.migrate(address(newWrapDepositRedeem));

        vm.selectFork(targetForkId);
        oldWrapMintBurn.migrate(address(newWrapMintBurn));
    }
}
