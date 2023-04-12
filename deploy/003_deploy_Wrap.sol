// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import { Wrap } from "../src/Wrap.sol";
import { WrapDepositRedeem } from "../src/WrapDepositRedeem.sol";
import { WrapMintBurn } from "../src/WrapMintBurn.sol";
import { WrapDeployer } from "./helpers/WrapDeployer.sol";

contract DeployWrap is WrapDeployer {
    function run() external {
        WrapDeployer.ValidatorConfig[]
            memory validators = new WrapDeployer.ValidatorConfig[](2);
        validators[0] = WrapDeployer.ValidatorConfig({
            validatorAddress: 0xebAa49C421A6158f280A04a0DEd08189110Cdf1F,
            isFirstCommittee: true,
            feeRecipient: 0xebAa49C421A6158f280A04a0DEd08189110Cdf1F
        });
        validators[1] = WrapDeployer.ValidatorConfig({
            validatorAddress: 0x675767258F825B707063a96590A31005f1944Ca8,
            isFirstCommittee: false,
            feeRecipient: 0x675767258F825B707063a96590A31005f1944Ca8
        });

        WrapDeployer.TokenConfig[]
            memory tokensWMB = new WrapDeployer.TokenConfig[](1);
        tokensWMB[0] = WrapDeployer.TokenConfig({
            name: "Wrapped XDC",
            symbol: "WXDC",
            token: address(0), // Sould be non-zero when upgrading
            mirrorToken: 0xE99500AB4A413164DA49Af83B9824749059b46ce,
            mirrorDecimals: 18,
            maxAmount: 1e24,
            minAmount: 1e18,
            dailyLimit: 1e20
        });

        WrapDeployer.WrapConfig memory wmbConfig = WrapDeployer.WrapConfig({
            wrapType: WrapDeployer.WrapType.MintBurn,
            firstCommitteeQuorum: 1,
            secondCommitteeQuorum: 1,
            protocolFeeBPS: 50,
            validatorFeeBPS: 50,
            validators: validators,
            tokens: tokensWMB,
            adminMultisig: 0x61D99Fd6AF946B8e35892e2A025fd01527e3DB92,
            pauserNode: 0xaef52Ba3119eE28695E5AaA0788F11015E1DaD46,
            timelockDelay: 5 minutes
        });

        WrapDeployer.TokenConfig[]
            memory tokensWDR = new WrapDeployer.TokenConfig[](1);
        tokensWDR[0] = WrapDeployer.TokenConfig({
            name: "",
            symbol: "",
            token: 0xE99500AB4A413164DA49Af83B9824749059b46ce,
            mirrorToken: address(0), // Will be replaced once WMB is deployed
            mirrorDecimals: 18,
            maxAmount: 1e24,
            minAmount: 1e18,
            dailyLimit: 1e20
        });

        WrapDeployer.WrapConfig memory wdrConfig = WrapDeployer.WrapConfig({
            wrapType: WrapDeployer.WrapType.DepositRedeem,
            firstCommitteeQuorum: 1,
            secondCommitteeQuorum: 1,
            protocolFeeBPS: 0,
            validatorFeeBPS: 50,
            validators: validators,
            tokens: tokensWDR,
            adminMultisig: 0x61D99Fd6AF946B8e35892e2A025fd01527e3DB92,
            pauserNode: 0xaef52Ba3119eE28695E5AaA0788F11015E1DaD46,
            timelockDelay: 5 minutes
        });

        require(
            tokensWMB.length == tokensWDR.length,
            "The tokens arrays should be the same length for both chains"
        );
        for (uint256 i = 0; i < tokensWMB.length; i++) {
            tokensWMB[i].mirrorToken = tokensWDR[i].token;
        }

        vm.createSelectFork(vm.rpcUrl("target"));

        vm.startBroadcast();
        Wrap wmb = deploy(wmbConfig);
        vm.stopBroadcast();

        for (uint256 i = 0; i < tokensWMB.length; i++) {
            tokensWDR[i].mirrorToken = wmb.tokens(i);
        }

        vm.createSelectFork(vm.rpcUrl("source"));

        vm.startBroadcast();
        deploy(wdrConfig);
        vm.stopBroadcast();
    }
}
