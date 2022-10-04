// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IAccessControlEnumerable} from "@openzeppelin/contracts/access/IAccessControlEnumerable.sol";

import {Multisig} from "../libraries/Multisig.sol";

/// @title Common interface for Wrap contracts
/// on FLR and EVM chains
interface IWrap is IAccessControlEnumerable {
    /// @dev Thrown when an operation is performed on a paused
    /// Phygital Redeemer contract.
    error ContractPaused();

    /// @dev Thrown when the token is not whitelisted, the amount
    /// being deposited/approved is not in the range of min/maxAmount
    /// or the current state of the requests doesn't match the
    error InvalidTokenAmount();

    /// @dev Thrown when the token config is invalid
    error InvalidTokenConfig();

    /// @dev Thrown when the fee being set is higher than the maximum
    /// allowed fee
    error FeeExceedsMaxFee();

    /// @dev Emitted when a user deposits
    /// @param id id associated to the request.
    /// @param token token deposited.
    /// @param amount amount of token deposited.
    /// @param to address to release the funds
    event Deposit(uint256 indexed id, address indexed token, uint256 amount, address to);

    /// @dev Emitted when a request is approved
    /// @param id id associated to the request.
    /// @param token token approved.
    /// @param amount amount of token approved.
    /// @param to address to release the funds
    event Approved(uint256 indexed id, address indexed token, uint256 amount, address to);

    /// @dev Emitted when a request is rejected
    /// @param hash of the request being rejected.
    event Rejected(bytes32 indexed hash);

    /// @dev Token info.
    /// @param maxAmount maximum amount allowed to deposit/approve.
    /// @param minAmount minimum amount allowed to deposit/approve.
    /// @notice set max amount to 0 to disable the token.
    struct TokenInfo {
        uint256 maxAmount;
        uint256 minAmount;
    }

    /// @dev Returns whether the contract has been paused.
    /// @return paused True if the contract is paused,
    /// false otherwise.
    function paused() external view returns (bool paused);

    /// @dev Set to the token configuration.
    /// @param tokenInfo the token token configuration.
    /// @notice set maxAmount to 0 to disable the token.
    /// @notice can be only called by the owner.
    function configureToken(address token, TokenInfo calldata tokenInfo) external;

    /// @dev Set the multisig config.
    /// @param config multisig config.
    /// @notice can be only called by the owner.
    function configureMultisig(Multisig.Config calldata config) external;

    /// @dev Deposit tokens.
    /// @param token token being deposited.
    /// @param amount amount of tokens being deposited.
    /// @param to address to release the tokens.
    /// @return the id associated to the request.
    function deposit(address token, uint256 amount, address to) external returns (uint256);

    /// @dev Approve request.
    /// @param id id of the request being approved.
    /// @param token token being approved.
    /// @param amount amount of tokens being approved.
    /// @param to address to release the tokens.
    function approve(uint256 id, address token, uint256 amount, address to) external;

    /// @dev Reject request.
    /// @param id id of the request being rejected.
    /// @param token token being rejected.
    /// @param amount amount of tokens being rejected.
    /// @param to address to release the tokens.
    function reject(uint256 id, address token, uint256 amount, address to) external;

    /// @dev Reject request.
    /// @param hash of the request being rejected.
    function reject(bytes32 hash) external;

    /// @dev Pauses the contract.
    /// @notice the contract can be paused by all addresses
    /// with pause role but can be unpaused only by the admin
    function pause() external;

    /// @dev Unpauses the contract
    /// @notice the contract can be paused by all addresses
    /// with pause role but can be unpaused only by the admin
    function unpause() external;
}
