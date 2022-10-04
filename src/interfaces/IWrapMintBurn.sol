// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IWrap} from "./IWrap.sol";

/// @title interface for Mint and Burn side of
/// of the Wraps contract
interface IWrapMintBurn is IWrap {
    /// @dev Get the protocol fees accumalated for a given token 
    /// @param token token address to get the fees.
    /// @return balance protocol fees balance for the token
    function accumalatedProtocolFees(address token) external view returns (uint256 balance);
    
    /// @dev Get the total validators fees accumalated for a given token 
    /// @param token token address to get the fees.
    /// @return balance validator fees balance for the token
    function accumalatedValidatorsFees(address token) external view returns (uint256 balance);

    /// @dev Get the protocol fee basis points
    function protocolFeeBPS() external view returns (uint16);

    /// @dev Get the validators fee basis points
    function validatorsFeeBPS() external view returns (uint16);

    /// @dev Configure fees
    /// @param protocolFeeBPS protocol fees in basis points
    /// @param validatorsFeeBPS validator fees in basis points
    /// @notice this function can only be called by the owner
    function configureFees(uint16 protocolFeeBPS, uint16 validatorsFeeBPS) external;

    /// @dev Allows the validator to claim fees accumalated
    /// @notice can only be called by a validator 
    function claimValidatorFees() external; 

    /// @dev Allows the owner to claim the protocol fees
    /// @notice can only be called by the owner 
    function claimProtocolFees(address token) external;
}
