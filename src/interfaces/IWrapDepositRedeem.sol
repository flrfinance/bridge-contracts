// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IWrap} from "./IWrap.sol";

/// @title interface for Deposit and Redeem side of
/// of the Wraps contract
interface IWrapDepositRedeem is IWrap {
    /// @dev Get the address of the custodian
    function custodian() external view returns (address);

    /// @dev Get the total validators fees accumalated for a given token
    /// @param token token address to get the fees.
    /// @return balance validator fees balance for the token
    function accumalatedValidatorsFees(address token) external view returns (uint256 balance);

    /// @dev Get the validators fee basis points
    function validatorsFeeBPS() external view returns (uint16);

    /// @dev Configure fees
    /// @param validatorsFeeBPS validator fees in basis points
    /// @notice can be only be called by the owner
    function configureFees(uint16 validatorsFeeBPS) external;

    /// @dev Allows the validator to claim fees accumalated
    /// @notice can only be called by a validator
    function claimValidatorFees() external;

    /// @dev Update the custodian address
    /// @param custodian address of the new custodian
    /// @notice can be only called by the owner
    function updateCustodian(address custodian) external;
}
