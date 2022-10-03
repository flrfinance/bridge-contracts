class DualMultisig
    n, m, p, q
    requests (hash => {
        approvalsA, 
        rejectionsA, 
        approvalsB, 
        rejectionsB, 
        status (0, 1, -1),
        rejectors: address[],
        approvers: address[],
        signer: (address => boolean),
    })
    points
    totalPoints 
    approve(address, hash, isA):
        request = requests[hash]
        require that the request status is undecided
        require that the request.signer[address] is false
        request.signer[address] = true
        request.approvers.add(address);
        (isA ? request.approvalsA : request.approvalsB)++;
        if request.approvalsA >= n and request.approvalsB >= p:
            request.status = approved
            totalPoints += approvers.length;
            for validator in request.approvers:
                points[validator]++
            return true
        return false
    reject(address, hash, isA)
        request = requests[hash]
        require that the request status is undecided
        require that the request.signer[address] is false
        request.signer[address] = true
        request.rejectors.add(address);
        (isA ? request.rejectionsA : request.rejectionsB)++
        if (isA ? request.rejectionsA == n : request.rejectionsB == p):
            request.status = rejected
            totalPoints += rejectors.length;
            for validators in request.rejectors:
                points[validators]++
            return true
        return false
    status(hash):
        requests[hash].status
    totalPoints():
        totalPoints
    points(address)
        points[address]
    clearPoints(address)
        totalPoints -= points[address]
        points[address] = 0

abstract BridgeCommon is AccessControl
    ---
    abstract onDeposit(id, {token, amount, to})
    abstract onApprove(id, {token, amount, to})
    ---
    depositCount;
    deposit({token, amount, to}) => id
        bridge is not paused
        token is whitelisted
        amount is range of min, max token amount
        id = ++depositCount
        amountDeposited = onDeposit(id, {token, amount, to})
        emit Deposit(id, token, amountDeposited, to)
    ---
    requests;
    DualMultisig multisig;
    approve(id, type, {token, amount, to}):
        bridge is not paused
        token is whitelisted
        amount is range of min, max token amount
        address is whitelisted with type
        hash = sha256(id, token, amount, to)
        isApproved = multisig.approve(address, hash, type)
        if isApproved:
            onApprove(id, {token, amount, to})
            emit some event
    reject(id, type, {token, amount, to}):
        hash = sha256(id, token, amount, to)
        reject(hash, type)
    reject(hash, type):
        bridge is not paused 
        address is whitelisted with type
        isRejected = multisig.reject(address, hash, type)
        if isRejected:
            emit some event
    ---
    ... access control methods ...
    whitelist({token, min, max}) only owner 
    pause() only owner
.
BridgeEVM is BridgeCommon
    accumalatedValidatorFees(token):
        return balanceOf token
    validatorFees({token, amount, to}):
        return fix percent of amount
    claimValidatorFees(type):
        address is whitelisted with type
        p = multisig.getPoints(address)
        t = multisig.totalPoints()
        multisigOfType.clearPoints(address)
        for c of whitelisted tokens
            transfer (accumalatedValidatorFees(c) * p / t) tokens of c
    ---
    private onDeposit(id, {token, amount, to}):
        transfer user tokens from user to custodian
    private onApprove(id, {token, amount, to}):
        vFee = validatorFees({token, amount, to})
        emit redeem(id, token, amount - vFee, to, vFee);
.
BridgeFLR is BridgeCommon
    accumalatedProtocolFees
    accumalatedValidatorFees(token):
        return balanceOf token - accumalatedProtocolFees[token] 
    protocolFees({token, amount, to}):
        return fix percent of amount
    validatorFees({token, amount, to}):
        return fix percent of amount
    claimValidatorFees(type):
        address is whitelisted with type
        p = multisig.getPoints(address)
        t = multisig.totalPoints()
        multisigOfType.clearPoints(address)
        for c of whitelisted tokens
            transfer (accumalatedValidatorFees(c) * p / t) tokens of c
    claimProtocolFees(token):
        address is owner
        pfee = accumalatedProtocolFees[token]
        accumalatedProtocolFees[token] -= pfee
        transfer pfee amount of tokens to address
    ---
    private onDeposit(id, {token, amount, to}):
        pFee = protocolFees({token, amount, to})
        accumalatedProtocolFees[token] += pFee
        transfer pFee user tokens to this contracts
        burn amount - pFee user tokens
        return amount - pFee
    private onApprove(id, {token, amount, to}):
        mint amount tokens
        pFee = protocolFees({token, amount, to})
        vFee = protocolFees({token, amount, to})
        accumalatedProtocolFees[token] += pFee
        transfer amount - pFee - vFee tokens to the user
