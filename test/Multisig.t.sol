// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { TestAsserter } from "./utils/TestAsserter.sol";
import { Multisig } from "../src/libraries/Multisig.sol";
import { MultisigHelpers } from "./utils/MultisigHelpers.sol";

contract MultisigTest is TestAsserter, MultisigHelpers {
    using Multisig for Multisig.DualMultisig;

    Multisig.DualMultisig multisig;

    struct RequestParams {
        uint256 id;
        uint256 message;
    }

    struct Request {
        RequestParams params;
        bytes32 hash;
    }

    address currentSigner;
    address signerInFirstCommittee;
    address signerInSecondCommittee;

    RequestParams testRequestParams;

    Request currentRequest;

    function _addSigner(Committee committee) internal {
        currentSigner = signer;
        multisig.addSigner(
            currentSigner,
            committee == Committee.First ? true : false
        );
    }

    modifier withSigner(Committee committee) {
        _addSigner(committee);
        _;
    }

    modifier withAnySigner() {
        _addSigner(block.number % 2 == 0 ? Committee.First : Committee.Second);
        _;
    }

    modifier withSignersFromBothCommittees() {
        signerInFirstCommittee = signerA;
        signerInSecondCommittee = signerB;

        if (!multisig.isSigner(signerInFirstCommittee)) {
            multisig.addSigner(signerInFirstCommittee, true);
        }

        if (!multisig.isSigner(signerInSecondCommittee)) {
            multisig.addSigner(signerInSecondCommittee, false);
        }

        _;
    }

    function _craftRequest(RequestParams memory requestParams) internal {
        bytes32 hash = keccak256(
            abi.encodePacked(requestParams.id, requestParams.message)
        );
        currentRequest = Request({ params: requestParams, hash: hash });
    }

    modifier withRequest() {
        _craftRequest(testRequestParams);
        _;
    }

    modifier withCustomRequest(RequestParams memory requestParams) {
        _craftRequest(requestParams);
        _;
    }

    function _craftUndecidedRequest(RequestParams memory requestParams)
        internal
        withCustomRequest(requestParams)
        withAnySigner
    {
        multisig.tryApprove(signer, currentRequest.hash, requestParams.id);
    }

    modifier withUndecidedRequest() {
        _craftUndecidedRequest(testRequestParams);
        _;
    }

    function _craftApprovedRequest(RequestParams memory requestParams)
        internal
        withCustomRequest(requestParams)
        withSignersFromBothCommittees
    {
        multisig.tryApprove(
            signerInFirstCommittee,
            currentRequest.hash,
            requestParams.id
        );
        multisig.tryApprove(
            signerInSecondCommittee,
            currentRequest.hash,
            requestParams.id
        );
    }

    modifier withApprovedRequest() {
        _craftApprovedRequest(testRequestParams);
        _;
    }

    modifier withCommitteeSize(uint8 size, Committee committee) {
        // TODO: Mock committeeSize to eq. maxCommitteeSize
        for (uint8 i = 1; i <= size; i++) {
            multisig.addSigner(vm.addr(i), committee == Committee.First);
        }
        _;
    }

    constructor() {
        testRequestParams = RequestParams({ id: 0, message: 1337 });

        Multisig.Config memory config = Multisig.Config(
            firstCommitteeAcceptanceQuorum,
            secondCommitteeAcceptanceQuorum
        );

        multisig.configure(config);
    }

    function testStatusWithNonExistentRequest() public {
        _assertEq(multisig.status(bytes32(0)), Multisig.RequestStatus.NULL);
    }

    function testStatusWithApprovedRequest() public withApprovedRequest {
        Multisig.Request memory request = multisig.requests[
            currentRequest.hash
        ];
        _assertEq(request.status, Multisig.RequestStatus.Accepted);
        _assertEq(multisig.status(currentRequest.hash), request.status);
    }

    function testStatusWithUndecidedRequest() public withUndecidedRequest {
        Multisig.Request memory request = multisig.requests[
            currentRequest.hash
        ];
        _assertEq(request.status, Multisig.RequestStatus.Undecided);
        _assertEq(multisig.status(currentRequest.hash), request.status);
    }

    function _testIsSigner(address possiblySigner) internal {
        assertTrue(multisig.isSigner(possiblySigner));
    }

    function testIsSignerForSignerFromFirstCommittee()
        public
        withSigner(Committee.First)
    {
        _testIsSigner(currentSigner);
    }

    function testIsSignerForSignerFromSecondCommittee()
        public
        withSigner(Committee.Second)
    {
        _testIsSigner(currentSigner);
    }

    function testPoints() public withApprovedRequest {
        assertEq(Multisig.points(multisig, signerInFirstCommittee), 1);
        assertEq(Multisig.points(multisig, signerInSecondCommittee), 1);
    }

    function testPointsRevertsIfSignerNotActive() public {
        vm.expectRevert(
            abi.encodeWithSelector(Multisig.SignerNotActive.selector, signer)
        );
        Multisig.points(multisig, signer);
    }

    function testConfigure() public {
        assertEq(
            multisig.firstCommitteeAcceptanceQuorum,
            firstCommitteeAcceptanceQuorum
        );
        assertEq(
            multisig.secondCommitteeAcceptanceQuorum,
            secondCommitteeAcceptanceQuorum
        );
    }

    function testConfigureRevertsOnInvalidFirstQuorum() public {
        vm.expectRevert(Multisig.InvalidConfiguration.selector);
        multisig.configure(Multisig.Config(0, secondCommitteeAcceptanceQuorum));

        vm.expectRevert(Multisig.InvalidConfiguration.selector);
        multisig.configure(
            Multisig.Config(
                Multisig.maxCommitteeSize + 1,
                secondCommitteeAcceptanceQuorum
            )
        );
    }

    function testConfigureRevertsOnInvalidSecondQuorum() public {
        vm.expectRevert(Multisig.InvalidConfiguration.selector);
        multisig.configure(Multisig.Config(firstCommitteeAcceptanceQuorum, 0));

        vm.expectRevert(Multisig.InvalidConfiguration.selector);
        multisig.configure(
            Multisig.Config(
                firstCommitteeAcceptanceQuorum,
                Multisig.maxCommitteeSize + 1
            )
        );
    }

    function _testAddSigner(Committee committee) internal {
        uint8 initialFirstCommitteeSize = multisig.firstCommitteeSize;
        uint8 initialSecondCommitteeSize = multisig.secondCommitteeSize;
        multisig.addSigner(signer, committee == Committee.First ? true : false);

        assertEq(
            multisig.firstCommitteeSize,
            committee == Committee.First
                ? initialFirstCommitteeSize + 1
                : initialFirstCommitteeSize
        );
        assertEq(
            multisig.secondCommitteeSize,
            committee == Committee.Second
                ? initialSecondCommitteeSize + 1
                : initialSecondCommitteeSize
        );

        Multisig.SignerInfo memory signerInfo = multisig.signers[signer];
        _assertEq(
            signerInfo.status,
            committee == Committee.First
                ? Multisig.SignerStatus.FirstCommittee
                : Multisig.SignerStatus.SecondCommittee
        );
        assertEq(
            signerInfo.index,
            multisig.firstCommitteeSize + multisig.secondCommitteeSize
        );
    }

    function testAddSignerToFirstCommittee() public {
        _testAddSigner(Committee.First);
    }

    function testAddSignerToSecondCommittee() public {
        _testAddSigner(Committee.Second);
    }

    function testAddSignerRevertsIfMaxFirstCommitteeSizeReached()
        public
        withCommitteeSize(Multisig.maxCommitteeSize, Committee.First)
    {
        vm.expectRevert(Multisig.MaxCommitteeSizeReached.selector);
        multisig.addSigner(signer, true);
    }

    function testAddSignerRevertsIfMaxSecondCommitteeSizeReached()
        public
        withCommitteeSize(Multisig.maxCommitteeSize, Committee.Second)
    {
        vm.expectRevert(Multisig.MaxCommitteeSizeReached.selector);
        multisig.addSigner(signer, false);
    }

    function testAddSignerRevertsIfAlreadyExistsInSameCommittee() public {
        multisig.addSigner(signer, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                Multisig.SignerAlreadyExists.selector,
                signer
            )
        );
        multisig.addSigner(signer, true);
    }

    function testAddSignerRevertsIfAlreadyExistsEvenInDifferentCommittee()
        public
    {
        multisig.addSigner(signer, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                Multisig.SignerAlreadyExists.selector,
                signer
            )
        );
        multisig.addSigner(signer, false);
    }

    function _testRemoveSigner(Committee committee)
        internal
        withSigner(committee)
    {
        multisig.removeSigner(currentSigner);
        Multisig.SignerInfo memory signerInfo = multisig.signers[currentSigner];
        _assertEq(signerInfo.status, Multisig.SignerStatus.Removed);
    }

    function testRemoveSignerFromFirstCommittee() public {
        _testRemoveSigner(Committee.First);
    }

    function testRemoveSignerFromSecondCommittee() public {
        _testRemoveSigner(Committee.Second);
    }

    function testRemoveSignerRevertsIfNotActive() public {
        vm.expectRevert(
            abi.encodeWithSelector(Multisig.SignerNotActive.selector, signer)
        );
        multisig.removeSigner(signer);
    }

    function _testRemoveSignerRevertsIfAlreadyRemoved(Committee committee)
        internal
    {
        _testRemoveSigner(committee);
        vm.expectRevert(
            abi.encodeWithSelector(
                Multisig.SignerNotActive.selector,
                currentSigner
            )
        );
        multisig.removeSigner(currentSigner);
    }

    function testRemoveSignerFromFirstCommitteeRevertsIfAlreadyRemoved()
        public
    {
        _testRemoveSignerRevertsIfAlreadyRemoved(Committee.First);
    }

    function testRemoveSignerFromSecondCommitteeRevertsIfAlreadyRemoved()
        public
    {
        _testRemoveSignerRevertsIfAlreadyRemoved(Committee.Second);
    }

    function testTryApproveRevertsIfSignerNotActive() public withRequest {
        uint256 id = currentRequest.params.id;
        bytes32 hash = currentRequest.hash;

        vm.expectRevert(
            abi.encodeWithSelector(Multisig.SignerNotActive.selector, signer)
        );
        multisig.tryApprove(signer, hash, id);
    }

    function testTryApproveIfSignerHasAlreadyApproved()
        public
        withAnySigner
        withRequest
    {
        uint256 id = currentRequest.params.id;
        bytes32 hash = currentRequest.hash;

        Multisig.RequestStatusTransition firstTransition = multisig.tryApprove(
            currentSigner,
            hash,
            id
        );
        _assertEq(
            firstTransition,
            Multisig.RequestStatusTransition.NULLToUndecided
        );

        Multisig.RequestStatusTransition secondTransition = multisig.tryApprove(
            currentSigner,
            hash,
            id
        );
        _assertEq(secondTransition, Multisig.RequestStatusTransition.Unchanged);

        Multisig.SignerInfo memory signerInfo = multisig.signers[currentSigner];
        Multisig.Request memory request = multisig.requests[hash];
        uint256 signerMask = 1 << signerInfo.index;
        assertEq(request.approvers, 0 | signerMask);
        _assertEq(request.status, Multisig.RequestStatus.Undecided);
    }

    function _testTryApproveCreatesNewRequest(Committee committee)
        internal
        withSigner(committee)
        withRequest
        returns (Multisig.Request memory)
    {
        uint256 id = currentRequest.params.id;
        bytes32 hash = currentRequest.hash;

        Multisig.RequestStatusTransition transition = multisig.tryApprove(
            currentSigner,
            hash,
            id
        );
        Multisig.SignerInfo memory signerInfo = multisig.signers[currentSigner];
        Multisig.Request memory request = multisig.requests[hash];
        uint256 signerMask = 1 << signerInfo.index;
        assertEq(request.approvers, request.approvers | signerMask);
        assertEq(multisig.approvedRequests[id], 0);
        _assertEq(request.status, Multisig.RequestStatus.Undecided);
        _assertEq(transition, Multisig.RequestStatusTransition.NULLToUndecided);

        return request;
    }

    function testTryApproveFromFirstCommitteeSigner() public {
        Multisig.Request memory request = _testTryApproveCreatesNewRequest(
            Committee.First
        );
        assertEq(request.approvalsFirstCommittee, 1);
        assertEq(request.approvalsSecondCommittee, 0);
    }

    function testTryApproveFromSecondCommitteeSigner() public {
        Multisig.Request memory request = _testTryApproveCreatesNewRequest(
            Committee.Second
        );
        assertEq(request.approvalsFirstCommittee, 0);
        assertEq(request.approvalsSecondCommittee, 1);
    }

    function _assertCorrectAcceptedRequestState(bytes32 hash, uint256 id)
        internal
    {
        Multisig.Request memory request = multisig.requests[hash];
        Multisig.SignerInfo memory firstSignerInfo = multisig.signers[
            signerInFirstCommittee
        ];
        Multisig.SignerInfo memory secondSignerInfo = multisig.signers[
            signerInSecondCommittee
        ];
        uint256 firstSignerMask = 1 << firstSignerInfo.index;
        uint256 secondSignerMask = 1 << secondSignerInfo.index;
        assertEq(request.approvers, 0 | firstSignerMask | secondSignerMask);
        assertEq(multisig.approvedRequests[id], hash);
        assertEq(multisig.totalPoints, 2);
        assertEq(Multisig.points(multisig, signerInSecondCommittee), 1);
        assertEq(Multisig.points(multisig, signerInSecondCommittee), 1);
        _assertEq(request.status, Multisig.RequestStatus.Accepted);
    }

    function testTryApproveAcceptsRequest()
        public
        withSignersFromBothCommittees
        withRequest
    {
        uint256 id = currentRequest.params.id;
        bytes32 hash = currentRequest.hash;

        Multisig.RequestStatusTransition firstTransition = multisig.tryApprove(
            signerInFirstCommittee,
            hash,
            id
        );
        _assertEq(
            firstTransition,
            Multisig.RequestStatusTransition.NULLToUndecided
        );

        Multisig.RequestStatusTransition secondTransition = multisig.tryApprove(
            signerInSecondCommittee,
            hash,
            id
        );
        _assertEq(
            secondTransition,
            Multisig.RequestStatusTransition.UndecidedToAccepted
        );

        _assertCorrectAcceptedRequestState(hash, id);
    }

    function testTryApproveForAlreadyApprovedRequest()
        public
        withApprovedRequest
    {
        uint256 id = currentRequest.params.id;
        bytes32 hash = currentRequest.hash;

        Multisig.RequestStatusTransition transition = multisig.tryApprove(
            signerInSecondCommittee,
            hash,
            id
        );
        _assertEq(transition, Multisig.RequestStatusTransition.Unchanged);

        _assertCorrectAcceptedRequestState(hash, id);
    }

    function testTryApproveRevertsForReusedId() public withApprovedRequest {
        uint256 id = currentRequest.params.id;
        uint256 message2 = 31337;
        bytes32 hash2 = keccak256(abi.encodePacked(id, message2));
        vm.expectRevert(Multisig.InvalidId.selector);
        multisig.tryApprove(signerInFirstCommittee, hash2, id);
    }

    function testTryExecuteWithoutApprovedRequest() public withRequest {
        uint256 id = currentRequest.params.id;
        bytes32 hash = currentRequest.hash;
        assertEq(multisig.nextExecutionIndex, 0);
        bool success = multisig.tryExecute(hash, id);
        assertEq(multisig.nextExecutionIndex, 0);
        assertFalse(success);
    }

    function testTryExecuteWithNextApprovedRequest()
        public
        withApprovedRequest
    {
        uint256 id = currentRequest.params.id;
        bytes32 hash = currentRequest.hash;

        assertEq(multisig.nextExecutionIndex, 0);
        bool success = multisig.tryExecute(hash, id);
        assertEq(multisig.nextExecutionIndex, 1);
        assertTrue(success);
    }

    function testTryExecuteWithApprovedButNotNextApprovedRequest() public {
        _craftRequest(RequestParams({ id: 0, message: 1337 }));
        _craftApprovedRequest(currentRequest.params);

        _craftRequest(RequestParams({ id: 1, message: 31337 }));
        _craftApprovedRequest(currentRequest.params);

        uint256 id = currentRequest.params.id;
        bytes32 hash = currentRequest.hash;

        assertEq(multisig.nextExecutionIndex, 0);
        bool success = multisig.tryExecute(hash, id);
        assertEq(multisig.nextExecutionIndex, 0);
        assertFalse(success);
    }

    function _testClearPoints(address signerToClear) internal {
        uint64 initialSignerPoints = Multisig.points(multisig, signerToClear);
        uint64 initialTotalPoints = multisig.totalPoints;
        uint64 pointsDeductedFromTotal = multisig.clearPoints(signerToClear);
        assertEq(pointsDeductedFromTotal, initialSignerPoints);
        assertEq(
            multisig.totalPoints,
            initialTotalPoints - pointsDeductedFromTotal
        );
        uint64 finalSignerPoints = Multisig.points(multisig, signerToClear);
        assertEq(finalSignerPoints, 0);
    }

    function testClearPoints() public withApprovedRequest {
        assertEq(Multisig.points(multisig, signerInFirstCommittee), 1);
        assertEq(Multisig.points(multisig, signerInSecondCommittee), 1);
        assertEq(multisig.totalPoints, 2);
        _testClearPoints(signerInFirstCommittee);
        assertEq(Multisig.points(multisig, signerInFirstCommittee), 0);
        assertEq(Multisig.points(multisig, signerInSecondCommittee), 1);
        assertEq(multisig.totalPoints, 1);
        _testClearPoints(signerInSecondCommittee);
        assertEq(Multisig.points(multisig, signerInFirstCommittee), 0);
        assertEq(Multisig.points(multisig, signerInSecondCommittee), 0);
        assertEq(multisig.totalPoints, 0);
    }

    function testClearPointsWithZeroPoints() public withAnySigner {
        _testClearPoints(signer);
    }

    function testClearPointsRevertsIfSignerNotActive() public {
        vm.expectRevert(
            abi.encodeWithSelector(Multisig.SignerNotActive.selector, signer)
        );
        multisig.clearPoints(signer);
    }
}
