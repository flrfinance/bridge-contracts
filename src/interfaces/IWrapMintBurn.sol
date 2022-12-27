// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { IWrap } from "./IWrap.sol";

/// @title Interface for the side of Wraps where tokens are minted and burnt.
interface IWrapMintBurn is IWrap {
    /// @dev Returns the total protocol fees accumulated for a given token.
    /// @param token Address of the token for which to check its
    /// corresponding accumulated protocol fees.
    /// @return balance Total accumulated protocol fees for the given token.
    function accumulatedProtocolFees(address token)
        external
        view
        returns (uint256 balance);

    /// @dev Returns the protocol fee basis points.
    function protocolFeeBPS() external view returns (uint16);

    /// @dev Configure protocol fees.
    /// @param protocolFeeBPS Protocol fee in basis points.
    /// @notice Can only be called by the owner.
    /// @notice Should update minAmountWithFees for all tokens.
    function configureProtocolFees(uint16 protocolFeeBPS) external;

    /// @dev Deploy a new token contract and link it to its mirror token.
    /// @param tokenName Name of the token to be created.
    /// @param tokenSymbol Symbol of the token to be created.
    /// @param mirrorToken Address of the token that will be deposited in
    /// the mirror contract.
    /// @param mirrorTokenDecimals Decimals of the mirror token.
    /// @param tokenInfo Info associated with the token.
    /// @return Address of the new wrap token.
    /// @notice Set maxAmount to zero to disable the token.
    /// @notice Can only be called by the owner.
    function createAddToken(
        string memory tokenName,
        string memory tokenSymbol,
        address mirrorToken,
        uint8 mirrorTokenDecimals,
        TokenInfo calldata tokenInfo
    ) external returns (address);

    /// @dev Allows the owner to claim the accumulated protocol fees.
    /// @notice Can only be called by the owner.
    function claimProtocolFees(address token) external;
}
