// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import {
    TimelockController
} from "@openzeppelin/contracts/governance/TimelockController.sol";

import { Multisig } from "../../src/libraries/Multisig.sol";
import { WrapDepositRedeem } from "../../src/WrapDepositRedeem.sol";
import { WrapMintBurn } from "../../src/WrapMintBurn.sol";
import { Wrap } from "../../src/Wrap.sol";
import { IWrap } from "../../src/interfaces/IWrap.sol";

library WrapDeployer {
    struct ValiatorConfig {
        address validator;
        bool isFirstCommittee;
        address feeRecipient;
    }

    struct TokenConfig {
        string name;
        string symbol;
        address mirror;
        address token;
        uint8 mirrorDecimals;
        uint256 maxAmount;
        uint256 minAmount;
        uint256 dailyLimit;
    }

    enum WrapType {
        MintBurn,
        DepositRedeem
    }

    struct WrapConfig {
        WrapType wrapType;
        uint8 firstCommitteeQuorum;
        uint8 secondCommitteeQuorum;
        uint8 protocolFeeBPS;
        uint8 validatorFeeBPS;
        ValiatorConfig[] validators;
        TokenConfig[] tokens;
        address adminMultisig;
        uint256 timeLockDelay;
    }

    function deploy(WrapConfig calldata wc) public {
        // Deploy the appropriate wraps contract.
        Multisig.Config memory c = Multisig.Config(
            wc.firstCommitteeQuorum,
            wc.secondCommitteeQuorum
        );
        console2.log("Deploying Wrap contract");
        Wrap w = wc.wrapType == WrapType.MintBurn
            ? Wrap(new WrapMintBurn(c, wc.protocolFeeBPS, wc.validatorFeeBPS))
            : Wrap(new WrapDepositRedeem(c, wc.validatorFeeBPS));
        console2.log("Wrap contract deployed at %d", address(w));

        // Add the initial set of valiators.
        ValiatorConfig[] memory validators = wc.validators;
        require(
            validators.length <= 256,
            "Initial set of validators should be less than 256"
        );
        for (uint16 i = 0; i < validators.length; i++) {
            ValiatorConfig memory v = validators[i];
            console2.log(
                "Adding validator: { validator: %d, isFirstCommittee: %d, feeRecipient: %d }",
                v.validator,
                v.isFirstCommittee,
                v.feeRecipient
            );
            w.addValidator(v.validator, v.isFirstCommittee, v.feeRecipient);
        }

        // Add the initial set of tokens.
        TokenConfig[] memory tokens = wc.tokens;
        for (uint256 i = 0; i < tokens.length; i++) {
            TokenConfig memory t = tokens[i];
            IWrap.TokenInfo memory ti = IWrap.TokenInfo({
                maxAmount: t.maxAmount,
                minAmount: t.minAmount,
                dailyLimit: t.dailyLimit
            });

            if (wc.wrapType == WrapType.MintBurn) {
                console2.log(
                    "Adding token: { name: %d, mirrorToken: %d }",
                    t.name,
                    t.mirror
                );
                address wrapToken = WrapMintBurn(address(w)).createAddToken(
                    t.name,
                    t.symbol,
                    t.mirror,
                    t.mirrorDecimals,
                    ti
                );
                console2.log("Wrap token deployed: { address: %d }", wrapToken);
            } else {
                console2.log(
                    "Adding token: { token: %d, mirrorToken: %d }",
                    t.token,
                    t.mirror
                );
                WrapDepositRedeem(address(w)).addToken(t.token, t.mirror, ti);
            }
        }

        // Deploy the TimelockController contract.
        console2.log("Deploying TimelockController");
        TimelockController tlc = new TimelockController(
            wc.timeLockDelay,
            new address[](0),
            new address[](0)
        );
        bytes32 DEFAULT_ADMIN_ROLE = tlc.DEFAULT_ADMIN_ROLE();
        tlc.grantRole(DEFAULT_ADMIN_ROLE, wc.adminMultisig);
        tlc.renounceRole(DEFAULT_ADMIN_ROLE, address(this));

        // Give the admin multisig weak admin role.
        bytes32 WEAK_ADMIN_ROLE = w.WEAK_ADMIN_ROLE();
        w.grantRole(WEAK_ADMIN_ROLE, wc.adminMultisig);
        w.renounceRole(WEAK_ADMIN_ROLE, address(this));

        // Give the TimelockController contract DEFAULT_ADMIN_ROLE.
        DEFAULT_ADMIN_ROLE = w.DEFAULT_ADMIN_ROLE();
        w.grantRole(DEFAULT_ADMIN_ROLE, address(tlc));
        w.renounceRole(DEFAULT_ADMIN_ROLE, address(this));
    }
    //TODO: add functions to verify and update deployment.
}
