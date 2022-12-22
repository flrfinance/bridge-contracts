// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { IWrap } from "./IWrap.sol";

/// @title interface for Deposit and Redeem side of
/// of the Wraps contract
interface IWrapDepositRedeem is IWrap {
    /// @dev Add a new token.
    /// @param token tokens that will be deposited in this contract.
    /// @param mirrorToken tokens that will be minted in the mirror contract.
    /// @param tokenInfo token info associated to the token.
    /// @notice set maxAmount to 0 to disable the token.
    /// @notice can be only called by the owner.
    function addToken(
        address token,
        address mirrorToken,
        TokenInfo calldata tokenInfo
    ) external;
}
