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

    /// @dev thrown if the request is already approved or
    /// rejected and additional action is not allowed.
    error RequestDecided(RequestStatus status);

    /// @dev thrown if signer tries to double sign for
    /// the same request .
    error SignerSigned();

    /// @dev thrown if the configuration parms being
    /// set is not valid.
    error InvalidConfiguration();

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
        Undecided,
        Accepted,
        Rejected
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
    /// @param rejectionsFirstCommittee number of rejections
    /// by the first committee.
    /// @param approvalSsecondCommittee number of approvals
    /// by the second committee.
    /// @param rejectionSsecondCommittee number of rejections
    /// by the second committee.
    /// @param status status of the request.
    /// @param approvers bitmask for signers from first and
    /// second committee committee that have accepted the request.
    /// @param rejectors bitmask for signers from first and
    /// second committee committee that have rejected the request.
    /// @notice approvers and rejectors are bitmasks. For eg. a set
    /// bit at position 2 in the approvers represents that the signer
    /// with index has approved the request.
    struct Request {
        uint8 approvalsFirstCommittee; // slot 1 (0 - 7 bits)
        uint8 rejectionsFirstCommittee; // slot 1 (8 - 15 bits)
        uint8 approvalsSecondCommittee; // slot 1 (16 - 23 bits)
        uint8 rejectionsSecondCommittee; // slot 1 (24 - 31 bits)
        RequestStatus status; // slot 1 (32 - 39 bits)
        // slot1 (40 - 255 spare bits)
        uint256 approvers; // slot 2
        uint256 rejectors; // slot 3
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
    /// @param firstCommitteeRejectionQuorum number of rejections
    /// required to reach rejection quoroum in the first committee.
    /// @param secondCommitteeAcceptanceQuorum number of acceptance
    /// required to reach acceptance quoroum in the second committee.
    /// @param secondCommitteeRejectionQuorum number of rejections
    /// required to reach rejection quoroum in the second committee.
    /// @param firstCommitteeSize size of the first committee.
    /// @param secondCommitteeSize size of the second committee.
    /// @param totalPoints total points accumalated among all the signers
    /// @param points an array of points where element i is the points
    /// accumalated by signer with index i.
    /// @param signers map signer address to signer info.
    /// @param requests maps request hash to request info.
    struct DualMultisig {
        uint8 firstCommitteeAcceptanceQuorum; // slot 1 (0 - 7bits)
        uint8 firstCommitteeRejectionQuorum; // slot 1 (8 - 15bits)
        uint8 secondCommitteeAcceptanceQuorum; // slot 1 (16 - 23bits)
        uint8 secondCommitteeRejectionQuorum; // slot 1 (24 - 31bits)
        uint8 firstCommitteeSize; // slot 1 (32 - 39bits)
        uint8 secondCommitteeSize; // slot 1 (40 - 47bits)
        uint64 totalPoints; // slot 1 (48 - 111 bits)
        // slot1 (112 - 255 spare bits)
        uint64[maxSignersSize] points;
        mapping(address => SignerInfo) signers;
        mapping(bytes32 => Request) requests;
    }

    /// @param firstCommitteeAcceptanceQuorum number of acceptance
    /// required to reach acceptance quoroum in the first committee.
    /// @param firstCommitteeRejectionQuorum number of rejections
    /// required to reach rejection quoroum in the first committee.
    /// @param secondCommitteeAcceptanceQuorum number of acceptance
    /// required to reach acceptance quoroum in the second committee.
    /// @param secondCommitteeRejectionQuorum number of rejections
    /// required to reach rejection quoroum in the second committee.
    /// @notice all of the config members should be > 0 and <=
    /// maxCommitteeSize
    struct Config {
        uint8 firstCommitteeAcceptanceQuorum;
        uint8 firstCommitteeRejectionQuorum;
        uint8 secondCommitteeAcceptanceQuorum;
        uint8 secondCommitteeRejectionQuorum;
    }

    /// @dev Returns a request status
    /// @param s the multisig to check the request
    /// @param hash the hash of the request being checked
    /// @return the request status
    function status(DualMultisig storage s, bytes32 hash) internal view returns (RequestStatus) {
        return s.requests[hash].status;
    }

    /// @dev Returns if a given address is a signer in the multisig.
    /// @param s the multisig to check the signer.
    /// @param signer the address to check if its a signer.
    /// @return true if the provided address is a signer.
    function isSigner(DualMultisig storage s, address signer) internal view returns (bool) {
        return s.signers[signer].status >= SignerStatus.FirstCommittee;
    }

    /// @dev Returns a points accumalated by a signer
    /// @param s the multisig to check the points
    /// @param signer the address of the signer
    /// @return the points accumalted by the signer
    function points(DualMultisig storage s, address signer) internal view returns (uint64) {
        SignerInfo memory signerInfo = s.signers[signer];
        if (signerInfo.status >= SignerStatus.FirstCommittee) {
            revert SignerNotActive(signer);
        }
        return s.points[signerInfo.index];
    }

    /// @dev Configures the multisig params
    function configure(DualMultisig storage s, Config memory c) internal {
        if (
            c.firstCommitteeAcceptanceQuorum == 0 || c.firstCommitteeAcceptanceQuorum > maxCommitteeSize
                || c.secondCommitteeAcceptanceQuorum == 0 || c.secondCommitteeAcceptanceQuorum > maxCommitteeSize
                || c.firstCommitteeRejectionQuorum == 0 || c.firstCommitteeRejectionQuorum > maxCommitteeSize
                || c.secondCommitteeRejectionQuorum == 0 || c.secondCommitteeRejectionQuorum > maxCommitteeSize
        ) {
            revert InvalidConfiguration();
        }
        s.firstCommitteeAcceptanceQuorum = c.firstCommitteeAcceptanceQuorum;
        s.firstCommitteeRejectionQuorum = c.firstCommitteeRejectionQuorum;
        s.secondCommitteeAcceptanceQuorum = c.secondCommitteeAcceptanceQuorum;
        s.secondCommitteeRejectionQuorum = c.secondCommitteeRejectionQuorum;
    }

    /// @dev Adds a new signer.
    /// @param s the multisig to add the signer to.
    /// @param signer the signer to be added.
    /// @param isFirstCommittee if the signer belongs to the
    /// first committee.
    function addSigner(DualMultisig storage s, address signer, bool isFirstCommittee) internal {
        uint8 committeeSize = (isFirstCommittee ? s.firstCommitteeSize : s.secondCommitteeSize);
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
        if (signerInfo.status >= SignerStatus.FirstCommittee) {
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
        uint8 count = 0;
        for (uint8 i = 0; i < maxSignersSize; i++) {
            if ((mask & (1 << i)) != 0) {
                s.points[i]++;
                count++;
            }
        }
        s.totalPoints += count;
    }

    /// @dev Approve a request.
    /// @param s the multisig for which request should be approved.
    /// @param signer the signer approving the request.
    /// @param hash the hash of the request being approved.
    /// @return bool true if the quorum was reached among both the
    /// committees and the request is accepted.
    function approve(DualMultisig storage s, address signer, bytes32 hash) internal returns (bool) {
        SignerInfo memory signerInfo = s.signers[signer];
        if (signerInfo.status >= SignerStatus.FirstCommittee) {
            revert SignerNotActive(signer);
        }
        Request storage request = s.requests[hash];
        if (request.status != RequestStatus.Undecided) {
            revert RequestDecided(request.status);
        }
        uint256 signerMask = 1 << signerInfo.index;
        if ((signerMask & (request.approvers | request.rejectors)) != 0) {
            revert SignerSigned();
        }

        request.approvers |= signerMask;
        if (signerInfo.status == SignerStatus.FirstCommittee) {
            ++request.approvalsFirstCommittee;
        } else {
            ++request.approvalsSecondCommittee;
        }

        if (
            request.approvalsFirstCommittee >= s.firstCommitteeAcceptanceQuorum
                && request.approvalsSecondCommittee >= s.secondCommitteeAcceptanceQuorum
        ) {
            request.status = RequestStatus.Accepted;
            incrementPoints(s, request.approvers);
            return true;
        }
        return false;
    }

    /// @dev Reject a request.
    /// @param s the multisig for which request should be rejected.
    /// @param signer the signer rejecting the request.
    /// @param hash the hash of the request being rejected.
    /// @return bool true if the quorum was reached in either of the
    /// committees and the request is rejected.
    function reject(DualMultisig storage s, address signer, bytes32 hash) internal returns (bool) {
        SignerInfo memory signerInfo = s.signers[signer];
        if (signerInfo.status >= SignerStatus.FirstCommittee) {
            revert SignerNotActive(signer);
        }
        Request storage request = s.requests[hash];
        if (request.status != RequestStatus.Undecided) {
            revert RequestDecided(request.status);
        }
        uint256 signerMask = 1 << signerInfo.index;
        if ((signerMask & (request.approvers | request.rejectors)) != 0) {
            revert SignerSigned();
        }

        request.rejectors |= signerMask;
        bool rejectionQuorumReached;
        if (signerInfo.status == SignerStatus.FirstCommittee) {
            rejectionQuorumReached = (++request.rejectionsFirstCommittee) >= s.firstCommitteeRejectionQuorum;
        } else {
            rejectionQuorumReached = (++request.rejectionsSecondCommittee) >= s.secondCommitteeRejectionQuorum;
        }

        if (rejectionQuorumReached) {
            request.status = RequestStatus.Rejected;
            incrementPoints(s, request.rejectors);
            return true;
        }
        return false;
    }

    /// @dev Clears the points accumalated by a signer.
    /// @param s the multisig for which the signer points should be cleared
    /// @param signer for whom the points should be cleared
    /// @return points of the signer
    function clearPoints(DualMultisig storage s, address signer) internal returns (uint64){
        SignerInfo memory signerInfo = s.signers[signer];
        if (signerInfo.status >= SignerStatus.FirstCommittee) {
            revert SignerNotActive(signer);
        }
        uint8 index = signerInfo.index;
        uint64 p = s.points[index];
        s.points[index] = 0;
        s.totalPoints -= p;
        return p;
    }
}
