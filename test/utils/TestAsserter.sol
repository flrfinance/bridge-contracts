// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { Multisig } from "../../src/libraries/Multisig.sol";
import { IWrap } from "../../src/interfaces/IWrap.sol";

contract TestAsserter is Test {
    function _assertEq(
        Multisig.SignerStatus _a,
        Multisig.SignerStatus _b
    ) internal {
        assertTrue(_a == _b);
    }

    function _assertEq(
        Multisig.RequestStatusTransition _a,
        Multisig.RequestStatusTransition _b
    ) internal {
        assertTrue(_a == _b);
    }

    function _assertEq(
        Multisig.RequestStatus _a,
        Multisig.RequestStatus _b
    ) internal {
        assertTrue(_a == _b);
    }
}
