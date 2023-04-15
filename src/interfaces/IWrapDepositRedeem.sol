// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { IWrap } from "./IWrap.sol";

/// @title Interface for the side of Wraps where tokens are deposited and
/// redeemed.
interface IWrapDepositRedeem is IWrap {
    /// @dev Allowlist a new token.
    /// @param token Address of the token that will be allowlisted.
    /// @param mirrorToken Address of the token that will be minted
    /// on the other side.
    /// @param tokenInfo Information associated with the token.
    /// @notice Set maxAmount to zero to disable the token.
    /// @notice Can only be called by the weak-admin.
    function addToken(
        address token,
        address mirrorToken,
        TokenInfo calldata tokenInfo
    ) external;
}
