// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @title Two Committee Multisig Library
/// @dev Implements a multisig with two committees.
/// A quoroum must be reached in both the
/// committees to approve the request. If either of
/// the committees reject a request, the request is
/// rejected. Each committee size is cannot grow
/// more that 128 members. For every quoroum the
/// signer that attested in favour of it is rewarded
/// a point. The intention is to use the accumalated
/// points of a signer to appropriately reward it
/// for its good deeds.
library Multisig {
    /// @dev thrown if an already existing signer is added.
    error SignerAlreadyExists(address signer);

    /// @dev thrown if signer performing some action doesn't
    /// exist or is removed.
    error SignerNotActive(address signer);

    /// @dev thrown if max committee size is reached and
    /// new signers can not be added.
    error MaxCommitteeSizeReached();

    /// @dev thrown if the configuration parms being
    /// set is not valid.
    error InvalidConfiguration();

    /// @dev thrown when the id has already been assigned
    /// to an apprroved request.
    error InvalidId();

    /// @dev thrown when a request too far in future or not yet
    /// approved is being executed
    error InvalidExecuteRequest();

    /// @dev maximum number of members in each committee.
    /// @notice that this number can not be further increased
    /// for the implementation below. The implementation
    /// uses bitmasks, and uint8 data type to gas optimize.
    /// These data structures will overflow if maxCommitteeSize
    /// is greater than 128.
    uint8 constant maxCommitteeSize = 128;

    /// @dev maximum number of members in both the committee
    /// combined.
    /// @notice that similar to maxCommitteeSize
    /// maxSignersSize also can not be increased more than 256.
    uint16 constant maxSignersSize = 256; // maxCommitteeSize * 2

    /// @dev Request statuses.
    enum RequestStatus {
        NULL, // request which doesn't exist
        Undecided, // request hasn't reached a quoroum
        Accepted // request approved
    }

    enum RequestStatusTransition {
        Unchanged,
        NULLToUndecided,
        UndecidedToAccepted
    }

    /// @dev Signer statuses.
    enum SignerStatus {
        Uninitialized,
        Removed,
        FirstCommittee,
        SecondCommittee
    }

    /// @dev Request info.
    /// @param approvalsFirstCommittee number of approvals
    /// by the first committee.
    /// @param approvalsSecondCommittee number of approvals
    /// by the second committee.
    /// @param status status of the request.
    /// @param approvers bitmask for signers from first and
    /// second committee committee that have accepted the request.
    /// @notice approvers is a bitmask. For eg. a set
    /// bit at position 2 in the approvers represents that the signer
    /// with index has approved the request.
    struct Request {
        uint8 approvalsFirstCommittee; // slot 1 (0 - 7 bits)
        uint8 approvalsSecondCommittee; // slot 1 (8 - 15 bits)
        RequestStatus status; // slot 1 (16 - 23 bits)
        // slot1 (23 - 255 spare bits)
        uint256 approvers; // slot 2
    }

    /// @dev Signer info.
    /// @param status status of the signer.
    /// @param index index of the signer.
    struct SignerInfo {
        SignerStatus status;
        uint8 index;
    }

    /// @dev DualMultisig
    /// @param firstCommitteeAcceptanceQuorum number of acceptance
    /// required to reach acceptance quoroum in the first committee.
    /// @param secondCommitteeAcceptanceQuorum number of acceptance
    /// required to reach acceptance quoroum in the second committee.
    /// @param firstCommitteeSize size of the first committee.
    /// @param secondCommitteeSize size of the second committee.
    /// @param totalPoints total points accumalated among all the signers
    /// @param nextExecutionIndex index of the request that will be executed next
    /// @param points an array of points where element i is the points
    /// accumalated by signer with index i.
    /// @param signers map signer address to signer info.
    /// @param requests maps request hash to request info.
    /// @param approvedRequests approved request for an id
    struct DualMultisig {
        uint8 firstCommitteeAcceptanceQuorum; // slot 1 (0 - 7bits)
        uint8 secondCommitteeAcceptanceQuorum; // slot 1 (8 - 15bits)
        uint8 firstCommitteeSize; // slot 1 (16 - 23bits)
        uint8 secondCommitteeSize; // slot 1 (24 - 31bits)
        uint64 totalPoints; // slot 1 (32 - 95 bits)
        // slot1 (95 - 255 spare bits)
        uint256 nextExecutionIndex;
        uint64[maxSignersSize] points;
        mapping(address => SignerInfo) signers;
        mapping(bytes32 => Request) requests;
        mapping(uint256 => bytes32) approvedRequests;
    }

    /// @param firstCommitteeAcceptanceQuorum number of acceptance
    /// required to reach acceptance quoroum in the first committee.
    /// @param secondCommitteeAcceptanceQuorum number of acceptance
    /// required to reach acceptance quoroum in the second committee.
    /// @notice all of the config members should be > 0 and <=
    /// maxCommitteeSize
    struct Config {
        uint8 firstCommitteeAcceptanceQuorum;
        uint8 secondCommitteeAcceptanceQuorum;
    }

    /// @dev Returns a request status
    /// @param s the multisig to check the request
    /// @param hash the hash of the request being checked
    /// @return the request status
    function status(DualMultisig storage s, bytes32 hash)
        internal
        view
        returns (RequestStatus)
    {
        return s.requests[hash].status;
    }

    /// @dev Returns if a given address is a signer in the multisig.
    /// @param s the multisig to check the signer.
    /// @param signer the address to check if its a signer.
    /// @return true if the provided address is a signer.
    function isSigner(DualMultisig storage s, address signer)
        internal
        view
        returns (bool)
    {
        return s.signers[signer].status >= SignerStatus.FirstCommittee;
    }

    /// @dev Returns a points accumalated by a signer
    /// @param s the multisig to check the points
    /// @param signer the address of the signer
    /// @return the points accumalted by the signer
    function points(DualMultisig storage s, address signer)
        internal
        view
        returns (uint64)
    {
        SignerInfo memory signerInfo = s.signers[signer];
        if (signerInfo.status < SignerStatus.FirstCommittee) {
            revert SignerNotActive(signer);
        }
        return s.points[signerInfo.index];
    }

    /// @dev Configures the multisig params
    function configure(DualMultisig storage s, Config memory c) internal {
        if (
            c.firstCommitteeAcceptanceQuorum == 0 ||
            c.firstCommitteeAcceptanceQuorum > maxCommitteeSize ||
            c.secondCommitteeAcceptanceQuorum == 0 ||
            c.secondCommitteeAcceptanceQuorum > maxCommitteeSize
        ) {
            revert InvalidConfiguration();
        }
        s.firstCommitteeAcceptanceQuorum = c.firstCommitteeAcceptanceQuorum;
        s.secondCommitteeAcceptanceQuorum = c.secondCommitteeAcceptanceQuorum;
    }

    /// @dev Adds a new signer.
    /// @param s the multisig to add the signer to.
    /// @param signer the signer to be added.
    /// @param isFirstCommittee if the signer belongs to the
    /// first committee.
    function addSigner(
        DualMultisig storage s,
        address signer,
        bool isFirstCommittee
    ) internal {
        uint8 committeeSize = (
            isFirstCommittee ? s.firstCommitteeSize : s.secondCommitteeSize
        );
        if (committeeSize == maxCommitteeSize) {
            revert MaxCommitteeSizeReached();
        }

        SignerInfo storage signerInfo = s.signers[signer];
        if (signerInfo.status != SignerStatus.Uninitialized) {
            revert SignerAlreadyExists(signer);
        }

        if (isFirstCommittee) {
            s.firstCommitteeSize++;
            signerInfo.status = SignerStatus.FirstCommittee;
        } else {
            s.secondCommitteeSize++;
            signerInfo.status = SignerStatus.SecondCommittee;
        }

        signerInfo.index = s.firstCommitteeSize + s.secondCommitteeSize;
    }

    /// @dev Removes a signer.
    /// @param s the multisig to remove the signer from.
    /// @param signer the signer to be removed.
    function removeSigner(DualMultisig storage s, address signer) internal {
        SignerInfo storage signerInfo = s.signers[signer];
        if (signerInfo.status < SignerStatus.FirstCommittee) {
            revert SignerNotActive(signer);
        }
        signerInfo.status = SignerStatus.Removed;
    }

    /// @dev Helper function to increment signer points as per a mask.
    /// @param s the multisig to increment the signer points.
    /// @param mask the bit mask to use for incrementing the points.
    /// @notice a set bit at index i in the mask should increment a
    /// single point of signer with index i.
    function incrementPoints(DualMultisig storage s, uint256 mask) private {
        uint16 count = 0;
        for (uint16 i = 0; i < maxSignersSize; i++) {
            if ((mask & (1 << i)) != 0) {
                s.points[i]++;
                count++;
            }
        }
        s.totalPoints += count;
    }

    /// @dev Approve a request if its not already approved.
    /// @param s the multisig for which request should be approved.
    /// @param signer the signer approving the request.
    /// @param hash the hash of the request being approved.
    /// @return the request status transition.
    function tryApprove(
        DualMultisig storage s,
        address signer,
        bytes32 hash,
        uint256 id
    ) internal returns (RequestStatusTransition) {
        Request storage request = s.requests[hash];
        // if request is accepted then simply return
        if (request.status == RequestStatus.Accepted) {
            return RequestStatusTransition.Unchanged;
        }

        SignerInfo memory signerInfo = s.signers[signer];
        // make sure the signer is valid
        if (signerInfo.status < SignerStatus.FirstCommittee) {
            revert SignerNotActive(signer);
        }
        // if another request with the same id is approved
        if (s.approvedRequests[id] != bytes32(0)) {
            revert InvalidId();
        }

        uint256 signerMask = 1 << signerInfo.index;
        // check if the signer has already signed
        if ((signerMask & request.approvers) != 0) {
            return RequestStatusTransition.Unchanged;
        }

        // add the signers to bitmask of approvers
        request.approvers |= signerMask;
        if (signerInfo.status == SignerStatus.FirstCommittee) {
            ++request.approvalsFirstCommittee;
        } else {
            ++request.approvalsSecondCommittee;
        }

        // if the quoroum has reached, update points and increment points
        if (
            request.approvalsFirstCommittee >=
            s.firstCommitteeAcceptanceQuorum &&
            request.approvalsSecondCommittee >=
            s.secondCommitteeAcceptanceQuorum
        ) {
            request.status = RequestStatus.Accepted;
            s.approvedRequests[id] = hash;
            incrementPoints(s, request.approvers);
            return RequestStatusTransition.UndecidedToAccepted;
        } else if (request.status == RequestStatus.NULL) {
            // if this the first approval change the request status to undecided
            request.status = RequestStatus.Undecided;
            return RequestStatusTransition.NULLToUndecided;
        }
        return RequestStatusTransition.Unchanged;
    }

    /// @dev try to execute the next approved request.
    /// @param s the multisig for which request should be executed.
    /// @param hash the hash of the request being executed.
    /// @param id the id of the request being executed.
    /// @return true if execution was successful.
    function tryExecute(
        DualMultisig storage s,
        bytes32 hash,
        uint256 id
    ) internal returns (bool) {
        if (id == s.nextExecutionIndex && s.approvedRequests[id] == hash) {
            s.nextExecutionIndex++;
            return true;
        }
        return false;
    }

    /// @dev Clears the points accumalated by a signer.
    /// @param s the multisig for which the signer points should be cleared
    /// @param signer for whom the points should be cleared
    /// @return points of the signer
    function clearPoints(DualMultisig storage s, address signer)
        internal
        returns (uint64)
    {
        SignerInfo memory signerInfo = s.signers[signer];
        if (signerInfo.status < SignerStatus.FirstCommittee) {
            revert SignerNotActive(signer);
        }
        uint8 index = signerInfo.index;
        uint64 p = s.points[index];
        s.points[index] = 0;
        s.totalPoints -= p;
        return p;
    }
}
