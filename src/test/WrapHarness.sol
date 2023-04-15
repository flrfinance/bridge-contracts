// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Multisig } from "../libraries/Multisig.sol";
import { Wrap } from "../Wrap.sol";

abstract contract WrapHarness is Wrap {
    constructor() {}

    function exposed_tokens(uint256 index) external view returns (address) {
        return tokens[index];
    }

    function exposed_tokensLength() external view returns (uint256) {
        return tokens.length;
    }

    function exposed_multisigCommittee()
        external
        view
        returns (
            uint8 firstCommitteeAcceptanceQuorum,
            uint8 secondCommitteeAcceptanceQuorum
        )
    {
        return (
            multisig.firstCommitteeAcceptanceQuorum,
            multisig.secondCommitteeAcceptanceQuorum
        );
    }

    function exposed_multisigFirstCommitteeSize()
        external
        view
        returns (uint8)
    {
        return multisig.firstCommitteeSize;
    }

    function exposed_multisigSecondCommitteeSize()
        external
        view
        returns (uint8)
    {
        return multisig.secondCommitteeSize;
    }

    function exposed_multisigSignerInfo(
        address signer
    ) external view returns (Multisig.SignerInfo memory) {
        return multisig.signers[signer];
    }

    function exposed_multisigGetApprovers(
        bytes32 hash
    ) external view returns (uint16[] memory, uint16) {
        return Multisig.getApprovers(multisig, hash);
    }

    function exposed_onDeposit(
        address token,
        uint256 amount
    ) external returns (uint256 fee) {
        return onDeposit(token, amount);
    }

    function exposed_depositFees(
        uint256 amount
    ) external view returns (uint256 fee) {
        return depositFees(amount);
    }

    function exposed_onExecute(
        address token,
        uint256 amount,
        address to
    ) external returns (uint256 fee, uint256 validatorFee) {
        return onExecute(token, amount, to);
    }

    function exposed_calculateFee(
        uint256 amount,
        uint16 feeBPS
    ) external pure returns (uint256) {
        return calculateFee(amount, feeBPS);
    }

    function exposed_hashRequest(
        uint256 id,
        address token,
        uint256 amount,
        address to
    ) external pure returns (bytes32) {
        return hashRequest(id, token, amount, to);
    }

    function exposed__addToken(
        address token,
        address mirrorToken,
        TokenInfo calldata tokenInfo
    ) external {
        return _addToken(token, mirrorToken, tokenInfo);
    }

    function exposed_maxFeeBPS() external pure returns (uint16) {
        return Wrap.maxFeeBPS;
    }

    function exposed_onMigrate(address _newContract) external {
        return onMigrate(_newContract);
    }
}
