// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import { Wrap } from "../src/Wrap.sol";
import { WrapDepositRedeem } from "../src/WrapDepositRedeem.sol";
import { WrapMintBurn } from "../src/WrapMintBurn.sol";
import { WrapDeployer } from "./helpers/WrapDeployer.sol";

contract DeployWrap is Script {
    function run() external {
        WrapDeployer.ValidatorConfig[]
            memory validators = new WrapDeployer.ValidatorConfig[](2);
        validators[0] = WrapDeployer.ValidatorConfig({
            validatorAddress: address(1),
            isFirstCommittee: true,
            feeRecipient: address(1)
        });
        validators[1] = WrapDeployer.ValidatorConfig({
            validatorAddress: address(2),
            isFirstCommittee: false,
            feeRecipient: address(2)
        });

        WrapDeployer.TokenConfig[]
            memory tokensWMB = new WrapDeployer.TokenConfig[](1);
        tokensWMB[0] = WrapDeployer.TokenConfig({
            name: "Wrapped XDC",
            symbol: "WXDC",
            token: 0xE99500AB4A413164DA49Af83B9824749059b46ce,
            mirrorToken: 0x767F3AB8900d8011856F18Da0Bf7cD46E85a429F,
            mirrorDecimals: 18,
            maxAmount: 1e24,
            minAmount: 1e18,
            dailyLimit: 1e20
        });

        WrapDeployer.WrapConfig memory wmbConfig = WrapDeployer.WrapConfig({
            wrapType: WrapDeployer.WrapType.MintBurn,
            firstCommitteeQuorum: 1,
            secondCommitteeQuorum: 2,
            protocolFeeBPS: 50,
            validatorFeeBPS: 50,
            validators: validators,
            tokens: tokensWMB,
            adminMultisig: address(1337),
            timelockDelay: 7 days
        });

        WrapDeployer.TokenConfig[]
            memory tokensWDR = new WrapDeployer.TokenConfig[](1);
        tokensWDR[0] = WrapDeployer.TokenConfig({
            name: "",
            symbol: "",
            token: 0xE99500AB4A413164DA49Af83B9824749059b46ce,
            mirrorToken: address(0),
            mirrorDecimals: 18,
            maxAmount: 1e24,
            minAmount: 1e18,
            dailyLimit: 1e20
        });

        WrapDeployer.WrapConfig memory wdrConfig = WrapDeployer.WrapConfig({
            wrapType: WrapDeployer.WrapType.DepositRedeem,
            firstCommitteeQuorum: 1,
            secondCommitteeQuorum: 2,
            protocolFeeBPS: 0,
            validatorFeeBPS: 50,
            validators: validators,
            tokens: tokensWDR,
            adminMultisig: address(1337),
            timelockDelay: 7 days
        });

        vm.createSelectFork(vm.rpcUrl("source"));

        vm.startBroadcast();
        Wrap wmb = WrapDeployer.deploy(wmbConfig);
        vm.stopBroadcast();

        //vm.makePersistent(address(wmb));
        tokensWDR[0].mirrorToken = address(wmb);

        vm.createSelectFork(vm.rpcUrl("target"));

        vm.startBroadcast();
        WrapDeployer.deploy(wdrConfig);
        vm.stopBroadcast();
    }
}
