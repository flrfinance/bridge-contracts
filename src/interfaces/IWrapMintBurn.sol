// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

/**
 * Copyright (C) 2023 Flare Finance B.V. - All Rights Reserved.
 *
 * This source code and any functionality deriving from it are owned by Flare
 * Finance BV and the use of it is only permitted within the official platforms
 * and/or original products of Flare Finance B.V. and its licensed parties. Any
 * further enquiries regarding this copyright and possible licenses can be directed
 * to partners@flr.finance.
 *
 * The source code and any functionality deriving from it are provided "as is",
 * without warranty of any kind, express or implied, including but not limited to
 * the warranties of merchantability, fitness for a particular purpose and
 * noninfringement. In no event shall the authors or copyright holder be liable
 * for any claim, damages or other liability, whether in an action of contract,
 * tort or otherwise, arising in any way out of the use or other dealings or in
 * connection with the source code and any functionality deriving from it.
 */

import { IWrap } from "./IWrap.sol";

/// @title Interface for the side of Wraps where tokens are minted and burnt.
interface IWrapMintBurn is IWrap {
    /// @dev Returns the total protocol fees accumulated for a given token.
    /// @param token Address of the token for which to check its
    /// corresponding accumulated protocol fees.
    /// @return balance Total accumulated protocol fees for the given token.
    function accumulatedProtocolFees(
        address token
    ) external view returns (uint256 balance);

    /// @dev Returns the protocol fee basis points.
    function protocolFeeBPS() external view returns (uint16);

    /// @dev Configure protocol fees.
    /// @param protocolFeeBPS Protocol fee in basis points.
    /// @notice Can only be called by the weak-admin.
    /// @notice Should update minAmountWithFees for all tokens.
    function configureProtocolFees(uint16 protocolFeeBPS) external;

    /// @dev Link a token to its mirror token. A new token will
    /// be deployed if existingToken is the zero address. Otherwise
    /// the existingToken will be used instead, which means that
    /// a contract migration is underway.
    /// @param tokenName Name of the token to be created.
    /// @param tokenSymbol Symbol of the token to be created.
    /// @param existingToken Address of an existing wrapped token that
    /// will be used instead of deploying a new token. A new token will
    /// be deployed if this is set as the zero address.
    /// @param mirrorToken Address of the token that will be deposited in
    /// the mirror contract.
    /// @param mirrorTokenDecimals Decimals of the mirror token.
    /// @param tokenInfo Info associated with the token.
    /// @return Address of the new wrap token.
    /// @notice Set maxAmount to zero to disable the token.
    /// @notice Can only be called by the weak-admin.
    function createAddToken(
        string memory tokenName,
        string memory tokenSymbol,
        address existingToken,
        address mirrorToken,
        uint8 mirrorTokenDecimals,
        TokenInfo calldata tokenInfo
    ) external returns (address);

    /// @dev Allows the weak-admin to claim the accumulated protocol fees.
    /// @param token Token to claim protocol fees for.
    /// @param recipient Address of the protocol fee recipient.
    /// @notice Can only be called by the weak-admin.
    function claimProtocolFees(address token, address recipient) external;
}
