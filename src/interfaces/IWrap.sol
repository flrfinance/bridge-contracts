// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {
    IAccessControlEnumerable
} from "@openzeppelin/contracts/access/IAccessControlEnumerable.sol";

import { Multisig } from "../libraries/Multisig.sol";

/// @title Common interface for Wrap contracts on FLR and EVM chains.
interface IWrap is IAccessControlEnumerable {
    /// @dev Thrown when an operation is performed on a paused Wrap contract.
    error ContractPaused();

    /// @dev Thrown when the token is not allowlisted or the amount
    /// being deposited/approved is not in the range of min/maxAmount.
    error InvalidTokenAmount();

    /// @dev Thrown when the token config is invalid.
    error InvalidTokenConfig();

    /// @dev Thrown when the fee being set is higher than the maximum
    /// fee allowed.
    error FeeExceedsMaxFee();

    /// @dev Thrown when the ID is not same as the approveIndex.
    error InvalidId();

    /// @dev Thrown when the recipient address is the zero address.
    error InvalidToAddress();

    /// @dev Thrown when the daily volume exceeds the dailyLimit.
    error DailyLimitExhausted();

    /// @dev Emitted when a user deposits.
    /// @param id ID associated with the request.
    /// @param token Token deposited.
    /// @param amount Amount of tokens deposited, minus the fee.
    /// @param to Address to release the funds to.
    /// @param fee Fee subtracted from the original deposited amount.
    event Deposit(
        uint256 indexed id,
        address indexed token,
        uint256 amount,
        address to,
        uint256 fee
    );

    /// @dev Emitted when a new request is created.
    /// @param id ID associated with the request.
    /// @param token Token requested.
    /// @param amount Amount of tokens requested.
    /// @param to Address to release the funds to.
    event Requested(
        uint256 indexed id,
        address indexed token,
        uint256 amount,
        address to
    );

    /// @dev Emitted when a request gets executed.
    /// @param id ID associated with the request.
    /// @param token Token approved.
    /// @param amount Amount approved (amount of token received by recipient address + fee).
    /// @param to Address to release the funds to.
    /// @param fee Fee charged on top of the approved amount.
    event Executed(
        uint256 indexed id,
        address indexed token,
        uint256 amount,
        address to,
        uint256 fee
    );

    /// @dev Token information.
    /// @param maxAmount Maximum amount to deposit/approve.
    /// @param minAmount Minimum amount to deposit/approve.
    /// @notice Set max amount to zero to disable the token.
    /// @param dailyLimit Daily volume limit.
    struct TokenInfo {
        uint256 maxAmount;
        uint256 minAmount;
        uint256 dailyLimit;
    }

    /// @dev Token info that is stored in the contact storage.
    /// @param maxAmount Maximum amount to deposit/approve.
    /// @param minAmount Minimum amount to approve.
    /// @param minAmountWithFees Minimum amount to deposit, with fees included.
    /// @param dailyLimit Daily volume limit.
    /// @param consumedLimit Consumed daily volume limit.
    /// @param lastUpdated Last timestamp when the consumed limit was set to 0.
    /// @notice Set max amount to zero to disable the token.
    /// @notice Set daily limit to 0 to disable the daily limit. Consumed limit should
    /// always be less than equal to dailyLimit.
    /// @notice The minAmountWithFees is minAmount + depositFees(minAmount).
    /// On deposit, the amount should be greater than minAmountWithFees such that,
    /// after fee deduction, it is still greater equal than minAmount.
    struct TokenInfoStore {
        uint256 maxAmount;
        uint256 minAmount;
        uint256 minAmountWithFees;
        uint256 dailyLimit;
        uint256 consumedLimit;
        uint256 lastUpdated;
    }

    /// @dev Request information.
    /// @param id ID associated with the request.
    /// @param token Token requested.
    /// @param amount Amount of tokens requested.
    /// @param to Address to release the funds to.
    struct RequestInfo {
        uint256 id;
        address token;
        uint256 amount;
        address to;
    }

    /// @dev Returns whether or not the contract has been paused.
    /// @return paused True if the contract is paused, false otherwise.
    function paused() external view returns (bool paused);

    /// @dev Returns the number of deposits.
    function depositIndex() external view returns (uint256);

    /// @dev Returns the index of the request that will be executed next.
    function nextExecutionIndex() external view returns (uint256);

    /// @dev Returns the validator fee basis points.
    function validatorFeeBPS() external view returns (uint16);

    /// @dev Returns the total validator fees accumulated for a given token.
    /// @param token Address of the token for which to check its
    /// corresponding accumulated validator fees.
    /// @return balance Total accumulated fees for the given token.
    function accumulatedValidatorFees(
        address token
    ) external view returns (uint256 balance);

    /// @dev Update a token's configuration information.
    /// @param tokenInfo The token's new configuration info.
    /// @notice Set maxAmount to zero to disable the token.
    /// @notice Can only be called by the owner.
    function configureToken(
        address token,
        TokenInfo calldata tokenInfo
    ) external;

    /// @dev Set the multisig configuration.
    /// @param config Multisig config.
    /// @notice Can only be called by the owner.
    function configureMultisig(Multisig.Config calldata config) external;

    /// @dev Configure validator fees.
    /// @param validatorFeeBPS Validator fee in basis points.
    /// @notice Can only be called by the owner.
    function configureValidatorFees(uint16 validatorFeeBPS) external;

    /// @dev Deposit tokens to bridge to the other side.
    /// @param token Token being deposited.
    /// @param amount Amount of tokens being deposited.
    /// @param to Address to release the tokens to on the other side.
    /// @return The ID associated to the request.
    function deposit(
        address token,
        uint256 amount,
        address to
    ) external returns (uint256);

    /// @dev Approve and/or execute a given request.
    /// @param id ID associated with the request.
    /// @param token Token requested.
    /// @param amount Amount of tokens requested.
    /// @param to Address to release the funds to.
    function approveExecute(
        uint256 id,
        address token,
        uint256 amount,
        address to
    ) external;

    /// @dev Approve and/or execute requests.
    /// @param requests Requests to approve and/or execute.
    function batchApproveExecute(RequestInfo[] calldata requests) external;

    /// @dev Pauses the contract.
    /// @notice The contract can be paused by all addresses
    /// with pause role but can only be unpaused by the admin.
    function pause() external;

    /// @dev Unpauses the contract.
    /// @notice The contract can be paused by all addresses
    /// with pause role but can only be unpaused by the admin.
    function unpause() external;

    /// @dev Add a new validator to the contract.
    /// @param validator Address of the validator.
    /// @param isFirstCommittee True when adding the validator to the first committee.
    /// @param feeRecipient Address of the fee recipient.
    /// false when adding the validator to the second committee.
    /// @notice Can only be called by the owner.
    function addValidator(
        address validator,
        bool isFirstCommittee,
        address feeRecipient
    ) external;

    /// @dev Change fee recipient for a validator.
    /// @param validator Address of the validator.
    /// @param feeRecipient Address of the new fee recipient.
    function configureValidatorFeeRecipient(
        address validator,
        address feeRecipient
    ) external;

    /// @dev Remove existing validator from the contract.
    /// @param validator Address of the validator.
    /// @notice Can only be called by the owner of the contract.
    /// @notice The fees accumulated by the validator are distributed before being removed.
    function removeValidator(address validator) external;

    /// @dev Allows to claim accumulated fees for a validator.
    /// @param validator Address of the validator.
    /// @notice Can be triggered by anyone but the fee is transfered to the
    /// set feeRecepient for the validator.
    function claimValidatorFees(address validator) external;
}
