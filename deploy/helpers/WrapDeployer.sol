// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {
    TimelockController
} from "@openzeppelin/contracts/governance/TimelockController.sol";

import { Multisig } from "../../src/libraries/Multisig.sol";
import { WrapDepositRedeem } from "../../src/WrapDepositRedeem.sol";
import { WrapMintBurn } from "../../src/WrapMintBurn.sol";
import { Wrap } from "../../src/Wrap.sol";
import { IWrap } from "../../src/interfaces/IWrap.sol";

contract WrapDeployer is Script {
    struct ValidatorConfig {
        address validatorAddress;
        bool isFirstCommittee;
        address feeRecipient;
    }

    struct TokenConfig {
        string name;
        string symbol;
        address token;
        address mirrorToken;
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
        ValidatorConfig[] validators;
        TokenConfig[] tokens;
        address adminMultisig;
        address pauserNode;
        uint256 timelockDelay;
    }

    function deploy(WrapConfig memory wc) public returns (Wrap) {
        // Deploy the appropriate wraps contract.
        Multisig.Config memory c = Multisig.Config(
            wc.firstCommitteeQuorum,
            wc.secondCommitteeQuorum
        );
        console2.log(
            "==================== DEPLOYING Wrap%s CONTRACT ====================",
            wc.wrapType == WrapType.MintBurn ? "MintBurn" : "DepositRedeem"
        );

        Wrap w = wc.wrapType == WrapType.MintBurn
            ? Wrap(new WrapMintBurn(c, wc.protocolFeeBPS, wc.validatorFeeBPS))
            : Wrap(new WrapDepositRedeem(c, wc.validatorFeeBPS));
        console2.log(
            "Wrap%s contract deployed at %s",
            wc.wrapType == WrapType.MintBurn ? "MintBurn" : "DepositRedeem",
            address(w)
        );

        // Add the initial set of valiators.
        ValidatorConfig[] memory validators = wc.validators;
        require(
            validators.length <= 256,
            "Initial set of validators should be less than 256"
        );
        for (uint16 i = 0; i < validators.length; i++) {
            ValidatorConfig memory v = validators[i];
            console2.log(
                "Adding validator: { address: %s, isFirstCommittee: %s, feeRecipient: %s }",
                v.validatorAddress,
                v.isFirstCommittee,
                v.feeRecipient
            );
            w.addValidator(
                v.validatorAddress,
                v.isFirstCommittee,
                v.feeRecipient
            );
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
                    "Adding token: { name: '%s', token: %s, mirrorToken: %s }",
                    t.name,
                    t.token,
                    t.mirrorToken
                );
                address wrapToken = WrapMintBurn(address(w)).createAddToken(
                    t.name,
                    t.symbol,
                    t.token,
                    t.mirrorToken,
                    t.mirrorDecimals,
                    ti
                );

                console2.log(
                    "%s at %s",
                    t.token == address(0)
                        ? "Wrap token deployed"
                        : "Used an existing wrap token that lives",
                    wrapToken
                );
            } else {
                console2.log(
                    "Adding token: { token: %s, mirrorToken: %s }",
                    t.token,
                    t.mirrorToken
                );
                WrapDepositRedeem(address(w)).addToken(
                    t.token,
                    t.mirrorToken,
                    ti
                );
            }
        }

        // Deploy the TimelockController contract.
        console2.log("Deploying TimelockController");
        address[] memory proposers = new address[](1);
        proposers[0] = wc.adminMultisig;
        address[] memory executors = new address[](1);
        executors[0] = wc.adminMultisig;
        TimelockController tlc = new TimelockController(
            wc.timelockDelay,
            proposers,
            executors
        );
        console2.log(
            "TimelockController contract deployed at %s",
            address(tlc)
        );

        bytes32 TIMELOCK_ADMIN_ROLE = tlc.TIMELOCK_ADMIN_ROLE();
        tlc.grantRole(TIMELOCK_ADMIN_ROLE, wc.adminMultisig);
        tlc.renounceRole(TIMELOCK_ADMIN_ROLE, msg.sender);

        console2.log(
            "TimelockController TIMELOCK_ADMIN_ROLE transferred to admin multisig at %s",
            address(wc.adminMultisig)
        );

        // Grant the pauser node pause role.
        bytes32 PAUSE_ROLE = w.PAUSE_ROLE();
        w.grantRole(PAUSE_ROLE, wc.pauserNode);

        console2.log(
            "Granted PAUSE_ROLE to pauser node at %s",
            address(wc.pauserNode)
        );

        // Give the admin multisig weak-admin role.
        bytes32 WEAK_ADMIN_ROLE = w.WEAK_ADMIN_ROLE();
        w.grantRole(WEAK_ADMIN_ROLE, wc.adminMultisig);
        w.renounceRole(WEAK_ADMIN_ROLE, msg.sender);

        console2.log(
            "Wrap WEAK_ADMIN_ROLE transferred to admin multisig at %s",
            address(wc.adminMultisig)
        );

        // Give the TimelockController contract DEFAULT_ADMIN_ROLE.
        bytes32 DEFAULT_ADMIN_ROLE = w.DEFAULT_ADMIN_ROLE();
        w.grantRole(DEFAULT_ADMIN_ROLE, address(tlc));
        w.renounceRole(DEFAULT_ADMIN_ROLE, msg.sender);

        console2.log(
            "Wrap DEFAULT_ADMIN_ROLE transferred to TimelockController at %s",
            address(tlc)
        );

        return w;
    }
    //TODO: add functions to verify and update deployment.
}
