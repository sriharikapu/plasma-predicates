struct deposit:
    untypedStart: uint256
    depositer: address
    precedingPlasmaBlockNumber: uint256

struct exitableRange:
    untypedStart: uint256
    isSet: bool

struct Exit:
    exiter: address
    plasmaBlockNumber: uint256
    ethBlockNumber: uint256
    tokenType: uint256
    untypedStart: uint256
    untypedEnd: uint256
    challengeCount: uint256 #predicate stuff below
    predicateAddress: address
    exitEncoding: bytes[1000]

struct inclusionChallenge:
    exitID: uint256
    ongoing: bool

struct invalidHistoryChallenge:
    exitID: uint256
    coinID: uint256
    blockNumber: uint256
    ongoing: bool # pred stuff below
    predicateAddress: address
    stateObject: bytes[1000]

struct tokenListing:
    # formula: ERC20 amount = (plasma coin amount * 10^decimalOffset)
    decimalOffset:  uint256 # the denomination offset between the plasma-wrapped coins and the ERC20's decimals.
    # address of the ERC20
    contractAddress: address

contract PredicateContract:
    def canStartExit(_exitEncoding: bytes[1000], _witness: bytes[1000]) -> bool: constant
    def canCancel(_exitEncoding: bytes[1000], _witness: bytes[1000]) -> bool: constant
    def doExitFinalization(_exitEncoding: bytes[1000]): modifying

contract SolidityABIHelper:
    def encodeExit(_state: bytes[1000], _typedStart: uint256, _typedEnd: uint256, _exitPlasmaBlock: uint256, _exitEthBlock: uint256) -> bytes[1000]: constant
    def decodePredicateFromState(_stateObject: bytes[1000]) -> address: constant

contract ERC20:
    def transferFrom(_from: address, _to: address, _value: uint256) -> bool: modifying
    def transfer(_to: address, _value: uint256) -> bool: modifying

contract Serializer:
    def getLeafHash(transactionEncoding: bytes[277]) -> bytes32: constant
    def decodeBlockNumber(transactionEncoding: bytes[277]) -> uint256: constant
    def decodeNumTransfers(transactionEncoding: bytes[277]) -> uint256: constant
    def decodeIthTransfer( index: int128, ransactionEncoding: bytes[277] ) -> bytes[68]: constant
    def bytes20ToAddress(addr: bytes[20]) -> address: constant
    def decodeSender( transferEncoding: bytes[68] ) -> address: constant
    def decodeRecipient( transferEncoding: bytes[68] ) -> address: constant
    def decodeTokenTypeBytes( transferEncoding: bytes[68] ) -> bytes[4]: constant
    def decodeTokenType( transferEncoding: bytes[68] ) -> uint256: constant
    def getTypedFromTokenAndUntyped(tokenType: uint256, coinID: uint256) -> uint256: constant
    def decodeTypedTransferRange(transferEncoding: bytes[68] ) -> (uint256, uint256): constant
    def decodeParsedSumBytes( transferProofEncoding: bytes[4821]  ) -> bytes[16]: constant
    def decodeLeafIndex( transferProofEncoding: bytes[4821] ) -> int128: constant
    def decodeSignature(transferProofEncoding: bytes[4821]) -> (uint256,  uint256, uint256): constant
    def decodeNumInclusionProofNodesFromTRProof(transferProof: bytes[4821]) -> int128: constant
    def decodeIthInclusionProofNode(index: int128, transferProofEncoding: bytes[4821]) -> bytes[48]: constant
    def decodeNumInclusionProofNodesFromTXProof(transactionProof: bytes[4821]) -> int128: constant
    def decodeNumTransactionProofs(transactionProofEncoding: bytes[4821]) -> int128: constant
    def decodeIthTransferProofWithNumNodes(index: int128, numInclusionProofNodes: int128, transactionProofEncoding: bytes[4821]) -> bytes[4821]: constant

# Events to log in web3
ListingEvent: event({tokenType: uint256, tokenAddress: address})
DepositEvent: event({plasmaBlockNumber: indexed(uint256), depositer: indexed(address), tokenType: uint256, untypedStart: uint256, untypedEnd: uint256})
SubmitBlockEvent: event({blockNumber: indexed(uint256), submittedHash: indexed(bytes32)})
BeginExitEvent: event({tokenType: indexed(uint256), untypedStart: indexed(uint256), untypedEnd: indexed(uint256), exiter: address, exitID: uint256})
FinalizeExitEvent: event({tokenType: indexed(uint256), untypedStart: indexed(uint256), untypedEnd: indexed(uint256), exitID: uint256, exiter: address})
ChallengeEvent: event({exitID: uint256, challengeID: indexed(uint256)})

# predicate related publics
solidityHelperAddr: public(address)

# operator related publics
operator: public(address)
nextPlasmaBlockNumber: public(uint256)
lastPublish: public(uint256) # ethereum block number of most recent plasma block
blockHashes: public(map(uint256, bytes32))

# token related publics
listings: public(map(uint256, tokenListing))
listingNonce: public(uint256)
listed: public(map(address, uint256)) #which address is what token type

weiDecimalOffset: public(uint256)

# deposit and exit related publics
exits: public(map(uint256, Exit))
exitNonce: public(uint256)
exitable: public(map(uint256, map(uint256, exitableRange))) # tokentype -> ( end -> start because it makes for cleaner code
deposits: public(map(uint256, map(uint256, deposit))) # first val is tokentype. also has end -> start for consistency
totalDeposited: public(map(uint256, uint256))

# challenge-related publics
inclusionChallenges: public(map(uint256, inclusionChallenge))
invalidHistoryChallenges: public(map(uint256, invalidHistoryChallenge))
challengeNonce: public(uint256)

isSetup: public(bool)

serializer: public(address)

# publics for ethereum message hash gen
# this is "\x19Ethereum Signed Message:\n32"
#PADDED_PREFIX: constant(bytes32) = 0x0000000019457468657265756d205369676e6564204d6573736167653a0a3332
#PADDED_PREFIX: constant(bytes32) = EMPTY_BYTES32
# pad and concat with self and slice at startup is the only way to get from string literal...
MESSAGE_PREFIX: public(bytes[28])

# period (of ethereum blocks) during which an exit can be challenged
CHALLENGE_PERIOD: public(uint256)
# period (of ethereum blocks) during which an invalid history history challenge can be responded
SPENTCOIN_CHALLENGE_PERIOD: public(uint256)
# minimum number of ethereum blocks between new plasma blocks
PLASMA_BLOCK_INTERVAL: constant(uint256) = 0

MAX_COINS_PER_TOKEN: public(uint256)

MAX_TREE_DEPTH: constant(int128) = 8
MAX_TRANSFERS: constant(uint256) = 4

@public
@constant
def checkTransferProofAndGetTypedBounds(
    leafHash: bytes32,
    blockNum: uint256,
    transferProof: bytes[4821]
) -> (uint256, uint256): # typedimplicitstart, typedimplicitEnd
    parsedSum: bytes[16] = Serializer(self.serializer).decodeParsedSumBytes(transferProof)
    numProofNodes: int128 = Serializer(self.serializer).decodeNumInclusionProofNodesFromTRProof(transferProof)
    leafIndex: int128 = Serializer(self.serializer).decodeLeafIndex(transferProof)

    computedNode: bytes[48] = concat(leafHash, parsedSum)
    totalSum: uint256 = convert(parsedSum, uint256)
    leftSum: uint256 = 0
    rightSum: uint256 = 0
    pathIndex: int128 = leafIndex
    
    for nodeIndex in range(MAX_TREE_DEPTH):
        if nodeIndex == numProofNodes:
            break
        proofNode: bytes[48] = Serializer(self.serializer).decodeIthInclusionProofNode(nodeIndex, transferProof)
        siblingSum: uint256 = convert(slice(proofNode, start=32, len=16), uint256)
        totalSum += siblingSum
        hashed: bytes32
        if pathIndex % 2 == 0:
            hashed = sha3(concat(computedNode, proofNode))
            rightSum += siblingSum
        else:
            hashed = sha3(concat(proofNode, computedNode))
            leftSum += siblingSum
        totalSumAsBytes: bytes[16] = slice( #This is all a silly trick since vyper won't directly convert numbers to bytes[]...classic :P
            concat(EMPTY_BYTES32, convert(totalSum, bytes32)),
            start=48,
            len=16
        )
        computedNode = concat(hashed, totalSumAsBytes)
        pathIndex /= 2
    rootHash: bytes[32] = slice(computedNode, start=0, len=32)
    rootSum: uint256 = convert(slice(computedNode, start=32, len=16), uint256)
    assert convert(rootHash, bytes32) == self.blockHashes[blockNum]
    return (leftSum, rootSum - rightSum)

COINID_BYTES: constant(int128) = 16
PROOF_MAX_LENGTH: constant(uint256) = 1152 # 1152 = TREENODE_LEN (48) * MAX_TREE_DEPTH (24) 
ENCODING_LENGTH_PER_TRANSFER: constant(int128) = 165

@public
@constant
def checkTransactionProofAndGetTypedTransfer(
        transactionEncoding: bytes[277],
        transactionProofEncoding: bytes[4821],
        transferIndex: int128
    ) -> (
        address, # transfer.to
        address, # transfer.from
        uint256, # transfer.start (typed)
        uint256, # transfer.end (typed)
        uint256 # transaction plasmaBlockNumber
    ):
    leafHash: bytes32 = Serializer(self.serializer).getLeafHash(transactionEncoding)
    plasmaBlockNumber: uint256 = Serializer(self.serializer).decodeBlockNumber(transactionEncoding)


    numTransfers: int128 = convert(Serializer(self.serializer).decodeNumTransfers(transactionEncoding), int128)
    numInclusionProofNodes: int128 = Serializer(self.serializer).decodeNumInclusionProofNodesFromTXProof(transactionProofEncoding)

    requestedTypedTransferStart: uint256 # these will be the ones at the trIndex we are being asked about by the exit game
    requestedTypedTransferEnd: uint256
    requestedTransferTo: address
    requestedTransferFrom: address
    for i in range(MAX_TRANSFERS):
        if i == numTransfers: #loop for max possible transfers, but break so we don't go past
            break
        transferEncoding: bytes[68] = Serializer(self.serializer).decodeIthTransfer(i, transactionEncoding)
        
        transferProof: bytes[4821] = Serializer(self.serializer).decodeIthTransferProofWithNumNodes(
            i,
            numInclusionProofNodes,
            transactionProofEncoding
        )

        implicitTypedStart: uint256
        implicitTypedEnd: uint256

        (implicitTypedStart, implicitTypedEnd) = self.checkTransferProofAndGetTypedBounds(
            leafHash,
            plasmaBlockNumber,
            transferProof
        )

        transferTypedStart: uint256
        transferTypedEnd: uint256

        (transferTypedStart, transferTypedEnd) = Serializer(self.serializer).decodeTypedTransferRange(transferEncoding)

        assert implicitTypedStart <= transferTypedStart
        assert transferTypedStart < transferTypedEnd
        assert transferTypedEnd <= implicitTypedEnd

        #check the sig
        v: uint256 # v
        r: uint256 # r
        s: uint256 # s
        (v, r, s) = Serializer(self.serializer).decodeSignature(transferProof)
        sender: address = Serializer(self.serializer).decodeSender(transferEncoding)

        messageHash: bytes32 = sha3(concat(self.MESSAGE_PREFIX, leafHash))
        assert sender == ecrecover(messageHash, v, r, s)

        if i == transferIndex:
            requestedTransferTo = Serializer(self.serializer).decodeRecipient(transferEncoding)
            requestedTransferFrom = sender
            requestedTypedTransferStart = transferTypedStart
            requestedTypedTransferEnd = transferTypedEnd

    return (
        requestedTransferTo,
        requestedTransferFrom,
        requestedTypedTransferStart,
        requestedTypedTransferEnd,
        plasmaBlockNumber
    )

### BEGIN CONTRACT LOGIC ###

@public
def setup(_operator: address, ethDecimalOffset: uint256, serializerAddr: address, solidityHelper: address): # last val should be properly hardcoded as a constant eventually

    assert self.isSetup == False
    self.CHALLENGE_PERIOD = 20
    self.SPENTCOIN_CHALLENGE_PERIOD =  self.CHALLENGE_PERIOD / 2

    self.solidityHelperAddr = solidityHelper
    
    self.operator = _operator
    self.nextPlasmaBlockNumber = 1 # starts at 1 so deposits before the first block have a precedingPlasmaBlock of 0 since it can't be negative (it's a uint)
    self.exitNonce = 0
    self.lastPublish = 0
    self.challengeNonce = 0
    self.exitable[0][0].isSet = True
    self.listingNonce = 1 # first list is ETH baby!!!

    self.MAX_COINS_PER_TOKEN = 256**12
    self.weiDecimalOffset = 0 # ethDecimalOffset setting to 0 for now until enabled in core
    paddedMessagePrefix: bytes32 = 0x0000000019457468657265756d205369676e6564204d6573736167653a0a3332
    #do the thing to get a bytes[28] prefix for message hash gen
    self.MESSAGE_PREFIX = slice(concat(paddedMessagePrefix, paddedMessagePrefix), start = 4, len = 28)

    self.serializer = serializerAddr

    self.isSetup = True
    
@public
def submitBlock(newBlockHash: bytes32):
    assert msg.sender == self.operator
    assert block.number >= self.lastPublish + PLASMA_BLOCK_INTERVAL

    #log the event for clients to check for
    log.SubmitBlockEvent(self.nextPlasmaBlockNumber, newBlockHash)

    # add the block to the contract
    self.blockHashes[self.nextPlasmaBlockNumber] = newBlockHash
    self.nextPlasmaBlockNumber += 1
    self.lastPublish = block.number

@public
def listToken(tokenAddress: address, denomination: uint256):
    assert self.listed[tokenAddress] == 0
    
    tokenType: uint256 = self.listingNonce
    self.listingNonce += 1

    self.listed[tokenAddress] = tokenType

    self.listings[tokenType].decimalOffset = 0 # denomination setting to 0 now until core supports
    self.listings[tokenType].contractAddress = tokenAddress

    self.exitable[tokenType][0].isSet = True # init the new token exitable ranges
    log.ListingEvent(tokenType, tokenAddress)

### BEGIN DEPOSITS AND EXITS SECTION ###

@private
def processDeposit(depositer: address, depositAmount: uint256, tokenType: uint256):
    assert depositAmount > 0

    oldUntypedEnd: uint256 = self.totalDeposited[tokenType]
    oldRange: exitableRange = self.exitable[tokenType][oldUntypedEnd] # remember, map is end -> start!

    self.totalDeposited[tokenType] += depositAmount # add deposit
    newUntypedEnd: uint256 = self.totalDeposited[tokenType] # this is how much there is now, so the end of this deposit.
    # removed, replace with per ERC -->    assert self.totalDeposited < MAX_END # make sure we're not at capacity
    clear(self.exitable[tokenType][oldUntypedEnd]) # delete old exitable range
    self.exitable[tokenType][newUntypedEnd] = oldRange #make exitable

    self.deposits[tokenType][newUntypedEnd].untypedStart = oldUntypedEnd # the range (oldUntypedEnd, newTotalDeposited) was deposited by the depositer
    self.deposits[tokenType][newUntypedEnd].depositer = depositer
    self.deposits[tokenType][newUntypedEnd].precedingPlasmaBlockNumber = self.nextPlasmaBlockNumber - 1

    # log the deposit so participants can take note
    log.DepositEvent(self.nextPlasmaBlockNumber - 1, depositer, tokenType, oldUntypedEnd, newUntypedEnd)


@public
@payable
def depositETH():
    weiMuiltiplier: uint256 = 10**self.weiDecimalOffset
    depositAmount: uint256 = as_unitless_number(msg.value) * weiMuiltiplier
    self.processDeposit(msg.sender, depositAmount, 0)

@public
def depositERC20(tokenAddress: address, depositSize: uint256):
    depositer: address = msg.sender

    tokenType: uint256 = self.listed[tokenAddress]
    assert tokenType > 0 # make sure it's been listed

    passed: bool = ERC20(tokenAddress).transferFrom(depositer, self, depositSize)
    assert passed

    tokenMultiplier: uint256 = 10**self.listings[tokenType].decimalOffset
    depositInPlasmaCoins: uint256 = depositSize * tokenMultiplier
    self.processDeposit(depositer, depositInPlasmaCoins, tokenType)

@public
def beginExit(tokenType: uint256, blockNumber: uint256, untypedStart: uint256, untypedEnd: uint256, stateObject: bytes[1000], witness: bytes[1000]) -> uint256:
    assert blockNumber < self.nextPlasmaBlockNumber

    # predicate stuff
    encodedExit: bytes[1000] = SolidityABIHelper(self.solidityHelperAddr).encodeExit(stateObject, untypedStart, untypedEnd, blockNumber, block.number) # todo type if doing ERC20
    exitPredicate: address = SolidityABIHelper(self.solidityHelperAddr).decodePredicateFromState(stateObject)

    assert PredicateContract(exitPredicate).canStartExit(encodedExit, witness)

    exiter: address = msg.sender
    exitID: uint256 = self.exitNonce

    # predicate stores
    self.exits[exitID].predicateAddress = exitPredicate
    self.exits[exitID].exitEncoding = encodedExit

    self.exits[exitID].exiter = exiter
    self.exits[exitID].plasmaBlockNumber = blockNumber
    self.exits[exitID].ethBlockNumber = block.number
    self.exits[exitID].tokenType = tokenType
    self.exits[exitID].untypedStart = untypedStart
    self.exits[exitID].untypedEnd = untypedEnd
    self.exits[exitID].challengeCount = 0

    self.exitNonce += 1

    #log the event
    log.BeginExitEvent(tokenType, untypedStart, untypedEnd, exiter, exitID)
    
    return exitID

@public
@constant
def checkRangeExitable(tokenType: uint256, untypedStart: uint256, untypedEnd: uint256, claimedExitableEnd: uint256):
    assert untypedEnd <= self.MAX_COINS_PER_TOKEN
    assert untypedEnd <= claimedExitableEnd
    assert untypedStart >= self.exitable[tokenType][claimedExitableEnd].untypedStart
    assert self.exitable[tokenType][claimedExitableEnd].isSet

# this function updates the exitable ranges to reflect a newly finalized exit.
@private
def removeFromExitable(tokenType: uint256, untypedStart: uint256, untypedEnd: uint256, exitableEnd: uint256):
    oldUntypedStart: uint256 = self.exitable[tokenType][exitableEnd].untypedStart
    #todo fix/check  the case with totally filled exit finalization
    if untypedStart != oldUntypedStart: # then we have a new exitable region to the left
        self.exitable[tokenType][untypedStart].untypedStart = oldUntypedStart # new exitable range from oldstart to the start of the exit (which has just become the end of the new exitable range)
        self.exitable[tokenType][untypedStart].isSet = True
    if untypedEnd != exitableEnd: # then we have leftovers to the right which are exitable
        self.exitable[tokenType][exitableEnd].untypedStart = untypedEnd # and it starts at the end of the finalized exit!
        self.exitable[tokenType][exitableEnd].isSet = True
    else: # otherwise, no leftovers on the right, so we can delete the map entry...
        if untypedEnd != self.totalDeposited[tokenType]: # ...UNLESS it's the rightmost deposited value, which we need to keep (even though it will be "empty", i.e. have start == end,because submitDeposit() uses it to make the new deposit exitable)
            clear(self.exitable[tokenType][untypedEnd])
        else: # and if it is the rightmost, 
            self.exitable[tokenType][untypedEnd].untypedStart = untypedEnd # start = end so won't ever be exitable, but allows for new deposit logic to work

@public
def finalizeExit(exitID: uint256, exitableEnd: uint256):
    exiter: address = self.exits[exitID].exiter
    exitETHBlockNumber: uint256 = self.exits[exitID].ethBlockNumber
    exitToken: uint256 = 0
    exitUntypedStart: uint256  = self.exits[exitID].untypedStart
    exitUntypedEnd: uint256 = self.exits[exitID].untypedEnd
    challengeCount: uint256 = self.exits[exitID].challengeCount
    tokenType: uint256 = self.exits[exitID].tokenType

    assert challengeCount == 0
    assert block.number > exitETHBlockNumber + self.CHALLENGE_PERIOD

    self.checkRangeExitable(tokenType, exitUntypedStart, exitUntypedEnd, exitableEnd)
    self.removeFromExitable(tokenType, exitUntypedStart, exitUntypedEnd, exitableEnd)

    pred: address = self.exits[exitID].predicateAddress
    exitEnc: bytes[1000] = self.exits[exitID].exitEncoding

    if tokenType == 0: # then we're exiting ETH
        weiMiltiplier: uint256 = 10**self.weiDecimalOffset
        exitValue: uint256 = (exitUntypedEnd - exitUntypedStart) / weiMiltiplier
        send(pred, as_wei_value(exitValue, "wei"))
        PredicateContract(pred).doExitFinalization(exitEnc)

    # log the event    
    log.FinalizeExitEvent(tokenType, exitUntypedStart, exitUntypedEnd, exitID, exiter)

@public
def challengeBeforeDeposit(
    exitID: uint256,
    coinID: uint256,
    depositUntypedEnd: uint256
):
    exitTokenType: uint256 = self.exits[exitID].tokenType

    # note: this can always be challenged because no response and all info on-chain, no invalidity period needed
    depositPrecedingPlasmaBlock: uint256 = self.deposits[exitTokenType][depositUntypedEnd].precedingPlasmaBlockNumber
    assert self.deposits[exitTokenType][depositUntypedEnd].depositer != ZERO_ADDRESS # requires the deposit to be a valid deposit and not something unset
    
    depositUntypedStart: uint256 = self.deposits[exitTokenType][depositUntypedEnd].untypedStart

    tokenType: uint256 = self.exits[exitID].tokenType
    depositTypedStart: uint256 = Serializer(self.serializer).getTypedFromTokenAndUntyped(tokenType, depositUntypedStart)
    depositTypedEnd: uint256 = Serializer(self.serializer).getTypedFromTokenAndUntyped(tokenType, depositUntypedEnd)

    assert coinID >= depositTypedStart
    assert coinID < depositTypedEnd

    assert depositPrecedingPlasmaBlock > self.exits[exitID].plasmaBlockNumber

    clear(self.exits[exitID])

@public
def challengeSpentCoin(
    exitID: uint256,
    witness: bytes[1000]
):
    # check we can still challenge
    exitethBlockNumberNumber: uint256 = self.exits[exitID].ethBlockNumber
    assert block.number < exitethBlockNumberNumber + self.SPENTCOIN_CHALLENGE_PERIOD

    exiter: address = self.exits[exitID].exiter
    exitPlasmaBlockNumber: uint256 = self.exits[exitID].plasmaBlockNumber
    exitTokenType: uint256 = self.exits[exitID].tokenType
    exitTypedStart: uint256 = Serializer(self.serializer).getTypedFromTokenAndUntyped(exitTokenType, self.exits[exitID].untypedStart)
    exitTypedEnd: uint256 = Serializer(self.serializer).getTypedFromTokenAndUntyped(exitTokenType, self.exits[exitID].untypedEnd)

    pred: address = self.exits[exitID].predicateAddress
    exitEnc: bytes[1000] = self.exits[exitID].exitEncoding
    
    cancelled: bool = PredicateContract(pred).canCancel(exitEnc, witness)
    assert cancelled

    # if all these passed, the coin was indeed spent.  CANCEL!
    clear(self.exits[exitID])

@private
def challengeInvalidHistory(
    exitID: uint256,
    coinID: uint256,
    typedStart: uint256,
    typedEnd: uint256,
    blockNumber: uint256,
    stateObject: bytes[1000],
    witness: bytes[1000]
):
    # check we can still challenge
    exitethBlockNumberNumber: uint256 = self.exits[exitID].ethBlockNumber
    assert block.number < exitethBlockNumberNumber + self.CHALLENGE_PERIOD

    # check the coinspend came before the exit block
    assert blockNumber < self.exits[exitID].plasmaBlockNumber

    # check the coinspend intersects the exit
    tokenType: uint256 = self.exits[exitID].tokenType
    exitTypedStart: uint256 = Serializer(self.serializer).getTypedFromTokenAndUntyped(tokenType, self.exits[exitID].untypedStart)
    exitTypedEnd: uint256 = Serializer(self.serializer).getTypedFromTokenAndUntyped(tokenType, self.exits[exitID].untypedEnd)

    assert coinID >= exitTypedStart
    assert coinID < exitTypedEnd

    # check the coinspend intersects the proven transfer
    assert coinID >= typedStart
    assert coinID < typedEnd

    # check the exit being challenged exists
    assert exitID < self.exitNonce

    # predicate stuff
    encodedExit: bytes[1000] = SolidityABIHelper(self.solidityHelperAddr).encodeExit(stateObject, typedStart, typedEnd, blockNumber, block.number) # todo type if doing ERC20
    exitPredicate: address = SolidityABIHelper(self.solidityHelperAddr).decodePredicateFromState(stateObject)

    assert PredicateContract(exitPredicate).canStartExit(encodedExit, witness)

    # get and increment challengeID
    challengeID: uint256 = self.challengeNonce
    self.exits[exitID].challengeCount += 1
    
    self.challengeNonce += 1

    #store pred stuff
    self.invalidHistoryChallenges[challengeID].predicateAddress = exitPredicate
    self.invalidHistoryChallenges[challengeID].stateObject = encodedExit

    # store challenge
    self.invalidHistoryChallenges[challengeID].ongoing = True
    self.invalidHistoryChallenges[challengeID].exitID = exitID
    self.invalidHistoryChallenges[challengeID].coinID = coinID
    self.invalidHistoryChallenges[challengeID].blockNumber = blockNumber

    # log the event so clients can respond
    log.ChallengeEvent(exitID, challengeID)

@public
def respondInvalidHistory(
        challengeID: uint256,
        witness: bytes[1000]
):
    assert self.invalidHistoryChallenges[challengeID].ongoing

    # check the response was between exit and challenge
    exitID: uint256 = self.invalidHistoryChallenges[challengeID].exitID
    exitPlasmaBlockNumber: uint256 = self.exits[exitID].plasmaBlockNumber
    chalBlockNumber: uint256 = self.invalidHistoryChallenges[challengeID].blockNumber

    # todo block checking figure out

    # predicate stuff
    pred: address = self.exits[exitID].predicateAddress
    exitEnc: bytes[1000] = self.exits[exitID].exitEncoding
    
    cancelled: bool = PredicateContract(pred).canCancel(exitEnc, witness)
    assert cancelled

    # response was successful
    clear(self.invalidHistoryChallenges[challengeID])
    self.exits[exitID].challengeCount -= 1
