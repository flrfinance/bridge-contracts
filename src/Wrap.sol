// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import {IWrap} from "./interfaces/IWrap.sol";
import {Multisig} from "./libraries/Multisig.sol";

abstract contract Wrap is IWrap, AccessControlEnumerable {
    using Multisig for Multisig.DualMultisig;

    /// @dev the role id for addresses that
    /// can pause the contract
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE");

    /// @dev True if the contracts are paused,
    /// false otherwise.
    bool public paused;

    /// @dev Map tokenAddress to tokenInfo
    mapping(address => TokenInfo) public tokenInfos;

    /// @dev Array of all the tokens added
    /// @notice a token in the list might not be active
    address[] tokens;

    /// @dev dual multisig to manage signers,
    /// attestations and request quoroum.
    Multisig.DualMultisig internal multisig;

    /// @dev the number of deposits.
    uint256 public depositIndex;

    constructor(Multisig.Config memory config) {
        multisig.configure(config);
    }

    function onDeposit(address token, uint256 amount) internal virtual returns (uint256 fee);

    function onExecute(address token, uint256 amount, address to) internal virtual returns (uint256 fee);

    /// @dev Modifier to make a function callable only when the contract is not paused.
    modifier isNotPaused() {
        if (paused == true) {
            revert ContractPaused();
        }
        _;
    }

    /// @dev Modifier to make a function callable only when the contract is not paused.
    modifier isValidTokenAmount(address token, uint256 amount) {
        TokenInfo memory t = tokenInfos[token];
        if (t.maxAmount <= amount || t.minAmount > amount) {
            revert InvalidTokenAmount();
        }
        _;
    }

    function lastExecutedIndex() external view returns (uint256) {
        return multisig.lastExecutedIndex;
    }

    /// @dev Internal function to calculate fees
    function calculateFee(uint256 amount, uint16 feeBPS) internal pure returns (uint256) {
        // 10,000 is 100%
        return (amount * feeBPS) / 10000;
    }

    /// @inheritdoc IWrap
    function deposit(address token, uint256 amount, address to)
        external
        isNotPaused
        isValidTokenAmount(token, amount)
        returns (uint256 id)
    {
        address _to = to == address(0) ? msg.sender : to;
        id = depositIndex;
        depositIndex++;
        uint256 fee = onDeposit(token, amount);
        emit Deposit(id, token, amount - fee, _to, fee);
    }

    /// @dev internal function to calculate the hash of the request.
    function hashRequest(uint256 id, address token, uint256 amount, address to) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(id, token, amount, to));
    }

    // @inheritdoc IWrap
    function approveExecute(uint256 id, address token, uint256 amount, address to)
        public
        isNotPaused
        isValidTokenAmount(token, amount)
    {
        // if the request id is lower than the last executed id then simply ignore the request
        if (id < multisig.lastExecutedIndex) {
            return;
        }

        bytes32 hash = hashRequest(id, token, amount, to);
        Multisig.RequestStatusTransition transition = multisig.tryApprove(msg.sender, hash, id);
        if (transition == Multisig.RequestStatusTransition.NULLToUndecided) {
            emit Requested(id, token, amount, to);
        }

        if (multisig.tryExecute(hash, id)) {
            uint256 fee = onExecute(token, amount, to);
            emit Executed(id, token, amount, to, fee);
        }
    }

    // @inheritdoc IWrap
    function batchApproveExecute(RequestInfo[] calldata requests) external {
        for (uint256 i = 0; i < requests.length; i++) {
            approveExecute(requests[i].id, requests[i].token, requests[i].amount, requests[i].to);
        }
    }

    /// @inheritdoc IWrap
    function configureToken(address token, TokenInfo calldata tokenInfo) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (tokenInfo.minAmount > 0) {
            TokenInfo memory ti = tokenInfos[token];
            if (ti.minAmount == 0 && ti.maxAmount == 0) {
                tokens.push(token);
            }
            tokenInfos[token] = tokenInfo;
        }
        revert InvalidTokenConfig();
    }

    /// @inheritdoc IWrap
    function configureMultisig(Multisig.Config calldata config) external onlyRole(DEFAULT_ADMIN_ROLE) {
        multisig.configure(config);
    }

    /// @inheritdoc IWrap
    function pause() external onlyRole(PAUSE_ROLE) {
        paused = true;
    }

    /// @inheritdoc IWrap
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        paused = false;
    }
}
