// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { IWrap } from "./IWrap.sol";

/// @title interface for Mint and Burn side of
/// of the Wraps contract
interface IWrapMintBurn is IWrap {
    /// @dev Get the protocol fees accumalated for a given token
    /// @param token token address to get the fees.
    /// @return balance protocol fees balance for the token
    function accumalatedProtocolFees(address token)
        external
        view
        returns (uint256 balance);

    /// @dev Get the protocol fee basis points
    function protocolFeeBPS() external view returns (uint16);

    /// @dev Configure protocol fees.
    /// @param protocolFeeBPS protocol fees in basis points.
    /// @notice this function can only be called by the owner.
    /// @notice this function should update the minAmountWithFees
    /// for all the tokens.
    function configureProtocolFees(uint16 protocolFeeBPS) external;

    /// @dev Create a wrap token link it to a mirror token.
    /// @param tokenName name of the token to be created.
    /// @param tokenSymbol symbol of the token to be created.
    /// @param mirrorToken the token that will be deposited in mirror contract.
    /// @param mirrorTokenDecimals decimals of the mirror token.
    /// @param tokenInfo token info associated to the token.
    /// @return the address of the new wrap token
    /// @notice set maxAmount to 0 to disable the token.
    /// @notice can be only called by the owner.
    function createAddToken(
        string memory tokenName,
        string memory tokenSymbol,
        address mirrorToken,
        uint8 mirrorTokenDecimals,
        TokenInfo calldata tokenInfo
    ) external returns (address);

    /// @dev Allows the owner to claim the protocol fees
    /// @notice can only be called by the owner
    function claimProtocolFees(address token) external;
}
