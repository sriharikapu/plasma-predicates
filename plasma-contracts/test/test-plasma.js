/* eslint-env mocha */
/* eslint-disable no-unused-expressions */

/* NOTE: filename has a 0 appended so that mocha loads this first,
so that contract deployment is only done once.  If you create a new
test, do it with a before() as in other files, not this one */

const chai = require('chai')
const expect = chai.expect
const assert = chai.assert

const BigNum = require('bn.js')

const EthCrypto = require('eth-crypto');

const plasmaUtils = require('plasma-utils')
const PlasmaMerkleSumTree = plasmaUtils.PlasmaMerkleSumTree
const models = plasmaUtils.serialization.models
const Transfer = models.Transfer
const UnsignedTransaction = models.UnsignedTransaction
const SignedTransaction = models.SignedTransaction
const TransferProof = models.TransferProof
const TransactionProof = models.TransactionProof
const genSequentialTXs = plasmaUtils.utils.getSequentialTxs
const genRandomTX = plasmaUtils.utils.genRandomTX
const setup = require('./setup-plasma')
const getCurrentChainSnapshot = setup.getCurrentChainSnapshot
const web3 = setup.web3
const CHALLENGE_PERIOD = 20

let rangePredicate
describe('Plasma Smart Contract', () => {
  let bytecode, abi, plasma, operatorSetup, freshContractSnapshot, serializer
  const dummyBlockHash = '0x0000000000000000000000000000000000000000000000000000000000000000'
  // BEGIN SETUP
  before(async () => {
    // setup ganache, deploy, etc.
    [
      bytecode, abi, plasma, operatorSetup, freshContractSnapshot, serializer, rangePredicate
    ] = await setup.setupPlasma()
  })
  describe('Deployment', () => {
    it('Should have compiled the vyper contract without errors', async () => {
      expect(abi).to.exist
      expect(bytecode).to.exist
      expect(plasma).to.exist
      expect(web3).to.exist
    })
    it('Should have setup() the contract for without errors', async () => {
      expect(operatorSetup).to.exist
    })
  })

  // BEGIN OPERATOR SECTION
  describe('Operator Usage', () => {
    it('should allow a block to be published by the operator', async () => {
      await plasma.methods.submitBlock(dummyBlockHash).send({ value: 0, from: web3.eth.accounts.wallet[0].address, gas: 4000000 }).catch((error) => { console.log('send callback failed: ', error) })
    })
  })

  // BEGIN DECODING SECTION
  describe('Serialization Decoding', () => {
    let randomTXEncoding, randomTX, randomTransferIndex, randomTransferEncoding
    let encodedSignature, decodedSignature, encodedTransferProof, decodedTransferProof, testTransferProof, encodedTransactionProof, decodedTransactionProof, transactionProof
    before(async () => {
      const numTransfers = 4
      const blockNum = 1
      randomTXEncoding = genRandomTX(blockNum, web3.eth.accounts.wallet[3].address, web3.eth.accounts.wallet[3].address, numTransfers)
      randomTX = new UnsignedTransaction(randomTXEncoding)
      randomTXEncoding = '0x' + randomTXEncoding
      randomTransferIndex = Math.floor(Math.random() * 4)
      randomTransferEncoding = '0x' + new Transfer(randomTX.transfers[randomTransferIndex]).encoded
      encodedSignature = '1bd693b532a80fed6392b428604171fb32fdbf953728a3a7ecc7d4062b1652c04224e9c602ac800b983b035700a14b23f78a253ab762deab5dc27e3555a750b354'
      decodedSignature = {
        v: '1b',
        r: 'd693b532a80fed6392b428604171fb32fdbf953728a3a7ecc7d4062b1652c042',
        s: '24e9c602ac800b983b035700a14b23f78a253ab762deab5dc27e3555a750b354'
      }
      encodedTransferProof = '00000000000000000000000000000003' + '00000000000000000000000000000004' + encodedSignature + '01' + '563f225cdc192264a90e7e4b402815479c71a16f1593afa4fc6323e18583472affffffffffffffffffffffffffffffff'
      decodedTransferProof = {
        parsedSum: new BigNum('3', 'hex'),
        leafIndex: new BigNum('4', 'hex'),
        inclusionProof: [
          '563f225cdc192264a90e7e4b402815479c71a16f1593afa4fc6323e18583472affffffffffffffffffffffffffffffff'
        ],
        signature: decodedSignature
      }
      testTransferProof = new TransferProof(decodedTransferProof)
      encodedTransactionProof = '01' + encodedTransferProof
      decodedTransactionProof = {
        transferProofs: [
          decodedTransferProof
        ]
      }
      transactionProof = new TransactionProof(decodedTransactionProof)
    })
    describe('Transfer Decoding', () => {
      it('should decode a transfer sender', async () => {
        const decoded = await serializer.methods.decodeSender(randomTransferEncoding).call()
        const expected = randomTX.transfers[randomTransferIndex].sender.toLowerCase()
        assert.equal(decoded.toLowerCase(), expected)
      })
      it('should decode a transfer recipient', async () => {
        const decoded = await serializer.methods.decodeRecipient(randomTransferEncoding).call()
        const expected = randomTX.transfers[randomTransferIndex].recipient.toLowerCase()
        assert.equal(decoded.toLowerCase(), expected)
      })
      it('should decode a token type bytes', async () => {
        const decoded = await serializer.methods.decodeTokenTypeBytes(randomTransferEncoding).call()
        const expected = '0x' + randomTX.transfers[randomTransferIndex].token.toString(16, 8)
        assert.equal(decoded, expected)
      })
      it('should decode a token type as uint', async () => {
        const decoded = await serializer.methods.decodeTokenType(randomTransferEncoding).call()
        const expected = randomTX.transfers[randomTransferIndex].token.toString()
        assert.equal(decoded, expected)
      })
      it('should convert an untyped coinID to typed given the tokenType', async () => {
        const untyped = 5
        const type = 2
        const typed = await serializer.methods.getTypedFromTokenAndUntyped(type, untyped).call()
        
        const expected = '158456325028528675187087900677'
        assert.equal(typed, expected)
      })
      it('should decode a transfer range', async () => {
        const decoded = await serializer.methods.decodeTypedTransferRange(randomTransferEncoding).call()
        const expectedType = randomTX.transfers[randomTransferIndex].token.toString(16, 8)
        const expectedStart = randomTX.transfers[randomTransferIndex].start.toString(16, 12)
        const expectedEnd = randomTX.transfers[randomTransferIndex].end.toString(16, 12)
        const expected = [
          new BigNum(expectedType + expectedStart, 16).toString(),
          new BigNum(expectedType + expectedEnd, 16).toString()
        ]
        assert.equal(decoded[0], expected[0])
        assert.equal(decoded[1], expected[1])
      })
    })
    describe('Transaction Decoding', () => {
      it('should getLeafHash of an encoded transaction', async () => {
        const possibleHash = await serializer.methods.getLeafHash(randomTXEncoding).call()
        assert.equal(possibleHash, randomTX.hash)
      })
      it('should decodeBlockNumber from a tx', async () => {
        const decoded = await serializer.methods.decodeBlockNumber(randomTXEncoding).call()
        const expected = new BigNum(randomTX.block).toString()
        assert.equal(decoded, expected)
      })
      it('should decodeNumTransfers from a tx', async () => {
        const decoded = await serializer.methods.decodeNumTransfers(randomTXEncoding).call()
        const expected = new BigNum(randomTX.transfers.length).toString()
        assert.equal(decoded, expected)
      })
      it('should decode the ith transfer', async () => {
        const index = 0
        const decoded = await serializer.methods.decodeIthTransfer(index, randomTXEncoding).call()
        const transfer = randomTX.transfers[index]
        const expected = '0x' + new Transfer(transfer).encoded.toString().toLowerCase()
        assert.equal(decoded, expected)
      })
    })
    describe('Transfer Proof Decoding', () => {
      it('should decodeParsedSumBytes', async () => {
        const decoded = await serializer.methods.decodeParsedSumBytes('0x' + encodedTransferProof).call()
        const expected = '0x' + testTransferProof.parsedSum.toString(16, 32)
        assert.equal(decoded, expected)
      })
      it('should decodeLeafIndex', async () => {
        const decoded = await serializer.methods.decodeLeafIndex('0x' + encodedTransferProof).call()

        const expected = testTransferProof.leafIndex.toString()
        assert.equal(decoded, expected)
      })
      it('should decodeSignature', async () => {
        const decoded = await serializer.methods.decodeSignature('0x' + encodedTransferProof).call()
        const expected = [
          new BigNum(testTransferProof.signature.v).toString(),
          new BigNum(testTransferProof.signature.r).toString(),
          new BigNum(testTransferProof.signature.s).toString()
        ]
        assert.equal(decoded[0], expected[0])
        assert.equal(decoded[1], expected[1])
        assert.equal(decoded[2], expected[2])
      })
      it('should decodeNumInclusionProofNodesFromTRProof', async () => {
        const decoded = await serializer.methods.decodeNumInclusionProofNodesFromTRProof('0x' + encodedTransferProof).call()
        const expected = testTransferProof.inclusionProof.length
        assert.equal(decoded, expected)
      })
      it('should decodeIthInclusionProofNode', async () => {
        const decoded = await serializer.methods.decodeIthInclusionProofNode(0, '0x' + encodedTransferProof).call()
        const expected = '0x' + new BigNum(testTransferProof.inclusionProof[0]).toString(16)
        assert.equal(decoded, expected)
      })
    })
    describe('Transaction Proof Decoding', () => {
      it('should decodeNumTransactionProofs', async () => {
        const decoded = await serializer.methods.decodeNumTransactionProofs('0x' + encodedTransactionProof).call()
        const expected = new BigNum(transactionProof.transferProofs.length).toString()
        assert.equal(decoded, expected)
      })

      it('should decodeNumInclusionProofNodesFromTXProof', async () => {
        const decoded = await serializer.methods.decodeNumInclusionProofNodesFromTXProof('0x' + encodedTransactionProof).call()
        const expected = testTransferProof.inclusionProof.length
        assert.equal(decoded, expected)
      })
      it('should decodeIthTransferProofWithNumNodes', async () => {
        const decoded = await serializer.methods.decodeIthTransferProofWithNumNodes(0, 1, '0x' + encodedTransactionProof).call()
        const expected = '0x' + encodedTransferProof
        assert.equal(decoded, expected)
      })
    })
  })

  // BEGIN PROOF CHECKING SECTION
  describe('Proof Checking', () => {
    let TXIndex, txs, tx, tree
    before(async () => {
      // tree for testing branch checking
      TXIndex = 0
      txs = genSequentialTXs(2, 1)
      tx = txs[TXIndex]
      tree = new PlasmaMerkleSumTree(txs)
    })
    it('should checkTransferProofAndGetTypedBounds', async () => {
      await setup.revertToChainSnapshot(freshContractSnapshot)
      freshContractSnapshot = await getCurrentChainSnapshot() // weird bug where ganache crashes if you load the same snapshot twice, so gotta "reset" it every time it's used.
      await plasma.methods.submitBlock('0x' + tree.root().hash).send({ value: 0, from: web3.eth.accounts.wallet[0].address, gas: 4000000 })

      const TRIndex = 0
      const unsigned = new UnsignedTransaction(tx)
      const possibleImplicitBounds = await plasma.methods.checkTransferProofAndGetTypedBounds(
        web3.utils.soliditySha3('0x' + unsigned.encoded),
        tx.block.toString(),
        '0x' + tree.getTransferProof(TXIndex, TRIndex).encoded // txindex only works here if all single-sends
      ).call()
      assert.equal(possibleImplicitBounds[0], new BigNum(0))
      assert(new BigNum(possibleImplicitBounds[1]).gte(new BigNum(txs[0].transfers[0].end)))
    })
    it('should checkTransactionProofAndGetTypedTransfer', async () => {
      const unsigned = new UnsignedTransaction(tx)
      const requestedTransfer = await plasma.methods.checkTransactionProofAndGetTypedTransfer(
        '0x' + unsigned.encoded,
        '0x' + tree.getTransactionProof(tx).encoded,
        0
      ).call()

      const expectedSender = tx.transfers[0].sender
      const expectedRecipient = tx.transfers[0].recipient
      const expectedStart = tx.transfers[0].start.toString()
      const expectedEnd = tx.transfers[0].end.toString()
      const expectedBlockNum = tx.block.toString()

      assert.equal(requestedTransfer[0], expectedRecipient)
      assert.equal(requestedTransfer[1], expectedSender)
      assert.equal(requestedTransfer[2], expectedStart)
      assert.equal(requestedTransfer[3], expectedEnd)
      assert.equal(requestedTransfer[4], expectedBlockNum)
    })
  })
  // BEGIN DEPOSITS AND EXITS SECTION
  describe('Deposits and Exits', () => {
    it('should allow a first deposit and add it to the deposits correctly', async () => {
      const depositSize = 50
      await plasma.methods.depositETH().send({ value: depositSize, from: web3.eth.accounts.wallet[1].address, gas: 4000000 })
      const exitableStart = await plasma.methods.exitable__untypedStart(0, depositSize).call()
      const depositStart = await plasma.methods.deposits__untypedStart(0, depositSize).call()
      const depositer = await plasma.methods.deposits__depositer(0, depositSize).call()
      assert.equal(exitableStart, '0')
      assert.equal(depositStart, '0')
      assert.equal(depositer, web3.eth.accounts.wallet[1].address)
    })
    it('should allow a second deposit and add it to the deposits correctly', async () => {
      const depositSize = 500
      await plasma.methods.depositETH().send({ value: depositSize, from: web3.eth.accounts.wallet[2].address, gas: 4000000 })
      const depositEnd = 550 // 550 hardcoded from above deposit of 50
      const exitableStart = await plasma.methods.exitable__untypedStart(0, depositEnd).call()
      const depositStart = await plasma.methods.deposits__untypedStart(0, depositEnd).call()
      const depositer = await plasma.methods.deposits__depositer(0, depositEnd).call()
      assert.equal(exitableStart, '0')
      assert.equal(depositStart, '50')
      assert.equal(depositer, web3.eth.accounts.wallet[2].address)
    })
    it.only('should allow that users `beginExit`s', async () => {
      const plasmaBlock = '0'
      const exitStart = '0'
      const exitEnd = '10'

      const alice = web3.eth.accounts.wallet[0].address
      const parameters = web3.eth.abi.encodeParameters(['address'], [alice])
      const rangeTransferStateObject = web3.eth.abi.encodeParameters(['bytes', 'address'], [parameters, rangePredicate._address])

      await plasma.methods.beginExit(0, plasmaBlock, exitStart, exitEnd, rangeTransferStateObject).send({ value: 0, from: alice, gas: 4000000 })
      const exitID = 0 // hardcode since this is all a deterministic test
      const exiter = await plasma.methods.exits__exiter(exitID).call()
      assert.equal(exiter, alice)
    })
    it('should properly finalize leftmost, rightmost, and middle exits', async () => {
      // this test finalizes exits in order of left, right, middle.
      // LEFT EXIT: (0, 10) -- beginExit() already happened in the last test
      await setup.mineNBlocks(CHALLENGE_PERIOD) // finalizing exits in order of left, right, middle for testing variety
      await plasma.methods.finalizeExit(0, 550).send({ value: 0, from: web3.eth.accounts.wallet[1].address, gas: 4000000 })

      // now do the end: exiting 300, 550 -> exitID 1
      const plasmaBlock = '0'
      await plasma.methods.beginExit(0, plasmaBlock, 300, 550).send({ value: 0, from: web3.eth.accounts.wallet[1].address, gas: 4000000 })
      await setup.mineNBlocks(CHALLENGE_PERIOD)
      await plasma.methods.finalizeExit(1, 550).send({ value: 0, from: web3.eth.accounts.wallet[1].address, gas: 4000000 })

      // now do the middle: 100,200 -> exitID 2
      await plasma.methods.beginExit(0, plasmaBlock, 100, 200).send({ value: 0, from: web3.eth.accounts.wallet[1].address, gas: 4000000 })
      await setup.mineNBlocks(CHALLENGE_PERIOD)
      await plasma.methods.finalizeExit(2, 300).send({ value: 0, from: web3.eth.accounts.wallet[1].address, gas: 4000000 })

      const firstExitableStart = await plasma.methods.exitable__untypedStart(0, 100).call()
      const secondExitableStart = await plasma.methods.exitable__untypedStart(0, 300).call()
      assert.equal(firstExitableStart, '10')
      assert.equal(secondExitableStart, '200')
    })
    it('should properly process a new deposit after the rightmost coin was exited', async () => {
      const depositSize = 420
      await plasma.methods.depositETH().send({ value: depositSize, from: web3.eth.accounts.wallet[2].address, gas: 4000000 })
      const depositEnd = 970 // total deposits were now 50 + 500 + 420
      const exitableStart = await plasma.methods.exitable__untypedStart(0, depositEnd).call()
      assert.equal(exitableStart, '550')
    })
  })
  describe('Exit games', () => {
    const [type, start, end] = [0, 0, 100]
    const [operator, alice, bob, carol, dave] = [
      web3.eth.accounts.wallet[0].address,
      web3.eth.accounts.wallet[1].address,
      web3.eth.accounts.wallet[2].address,
      web3.eth.accounts.wallet[3].address,
      web3.eth.accounts.wallet[4].address
    ]
    const [blockNumA, blockNumB, blockNumC] = [3, 4, 5] // publishing 2 empty blocks first and index starts at 1 currently
    const txAUnsigned = new UnsignedTransaction({
      block: blockNumA,
      transfers: [
        {
          sender: alice,
          recipient: bob,
          token: type,
          start: start,
          end: end
        }
      ]
    })
    const txA = new SignedTransaction({
      ...txAUnsigned,
      ...{ signatures: [plasmaUtils.utils.sign(txAUnsigned.hash, web3.eth.accounts.wallet[1].privateKey)] }
    })
    const txBUnsigned= new UnsignedTransaction({
      block: blockNumB,
      transfers: [
        {
          sender: bob,
          recipient: carol,
          token: type,
          start: start,
          end: end + 100 // used for invalidHistoryDepositResponse below
        }
      ]
    })
    const txB = new SignedTransaction({
      ...txBUnsigned,
      ...{ signatures: [plasmaUtils.utils.sign(txBUnsigned.hash, web3.eth.accounts.wallet[2].privateKey)] }
    })
    const txCUnsigned = new UnsignedTransaction({
      block: blockNumC,
      transfers: [
        {
          sender: carol,
          recipient: dave,
          token: type,
          start: start,
          end: end
        }
      ]
    })
    const txC = new SignedTransaction({
      ...txCUnsigned,
      ...{ signatures: [plasmaUtils.utils.sign(txCUnsigned.hash, web3.eth.accounts.wallet[3].privateKey)] }
    })

    // Get some random transactions so make a tree with.  Note that they will be invalid--but we're not checking them so who cares! :P
    const otherTXs = genSequentialTXs(300).slice(200)

    const blocks = {
      A: new PlasmaMerkleSumTree([txA].concat(otherTXs)),
      B: new PlasmaMerkleSumTree([txB].concat(otherTXs)),
      C: new PlasmaMerkleSumTree([txC].concat(otherTXs))
    }

    let chalNonce = 0
    let exitNonce = 0
    before(async function () {
      await setup.revertToChainSnapshot(freshContractSnapshot)
      freshContractSnapshot = await getCurrentChainSnapshot() // weird bug where ganache crashes if you load the same snapshot twice, so gotta "reset" it every time it's used.
      await plasma.methods.submitBlock(dummyBlockHash).send({ value: 0, from: operator, gas: 4000000 }).catch((error) => { console.log('send callback failed: ', error) })
      await plasma.methods.submitBlock(dummyBlockHash).send({ value: 0, from: operator, gas: 4000000 }).catch((error) => { console.log('send callback failed: ', error) })

      await plasma.methods.depositETH().send({ value: end, from: alice, gas: 4000000 })

      await plasma.methods.submitBlock('0x' + blocks['A'].root().hash).send({ value: 0, from: operator, gas: 4000000 })
      await plasma.methods.submitBlock('0x' + blocks['B'].root().hash).send({ value: 0, from: operator, gas: 4000000 })
      await plasma.methods.submitBlock('0x' + blocks['C'].root().hash).send({ value: 0, from: operator, gas: 4000000 })
    })
    it('should allow inclusionChallenges and respondTransactionInclusion', async () => {
      await plasma.methods.beginExit(0, 5, start, end).send({ value: 0, from: dave, gas: 4000000 })
      let exitID = exitNonce // this will be 0 since it's the first exit
      exitNonce++

      await plasma.methods.challengeInclusion(exitID).send({ value: 0, from: alice, gas: 4000000 })
      let chalID = chalNonce // remember, the challenge nonce only counts respondable challenges (inv history and inclusion)
      chalNonce++

      const chalCount = await plasma.methods.exits__challengeCount(exitID).call()
      assert.equal(chalCount, '1')
      debugger

      const transferIndex = 0
      const unsigned = new UnsignedTransaction(txC)
      await plasma.methods.respondTransactionInclusion(
        chalID,
        transferIndex,
        '0x' + unsigned.encoded,
        '0x' + blocks['C'].getTransactionProof(txC).encoded
      ).send()
      debugger

      const newChalCount = await plasma.methods.exits__challengeCount(exitID).call()
      assert.equal(newChalCount, '0')

      const isOngoing = await plasma.methods.inclusionChallenges__ongoing(chalID).call()
      assert.equal(isOngoing, false)
    })
    it('should allow respondDepositInclusion s', async () => {
      await plasma.methods.beginExit(0, 2, start, end).send({ value: 0, from: alice, gas: 4000000 })
      let exitID = exitNonce
      exitNonce++

      await plasma.methods.challengeInclusion(exitID).send({ value: 0, from: alice, gas: 4000000 })
      let chalID = chalNonce
      chalNonce++

      const chalCount = await plasma.methods.exits__challengeCount(exitID).call()
      assert.equal(chalCount, '1')

      await plasma.methods.respondDepositInclusion(
        chalID,
        end
      ).send()

      const newChalCount = await plasma.methods.exits__challengeCount(exitID).call()
      assert.equal(newChalCount, '0')

      const isOngoing = await plasma.methods.inclusionChallenges__ongoing(chalID).call()
      assert.equal(isOngoing, false)
    })
    it.only('should allow Spent Coin Challenges to cancel exits', async () => {
      const plasmaBlock = '0'
      const exitStart = '0'
      const exitEnd = '10'

      const alice = web3.eth.accounts.wallet[0].address
      const parameters = web3.eth.abi.encodeParameters(['address'], [alice])
      const rangeTransferStateObject = web3.eth.abi.encodeParameters(['bytes', 'address'], [parameters, rangePredicate._address])

      await plasma.methods.beginExit(0, plasmaBlock, exitStart, exitEnd, rangeTransferStateObject).send({ value: 0, from: alice, gas: 4000000 })

      debugger

      const exitID = exitNonce
      exitNonce++

      const message = web3.eth.abi.encodeParameters(['uint256', 'uint256', 'uint256'], [exitStart, exitEnd, plasmaBlock])
      const messageHash = web3.utils.sha3(message)
      const sig = EthCrypto.sign(web3.eth.accounts.wallet[0].privateKey, messageHash)

      const witness = web3.eth.abi.encodeParameters(['uint256', 'uint256', 'bytes'], [exitStart, exitEnd, sig])

      debugger

      await plasma.methods.challengeSpentCoin(
        exitID,
        witness
      ).send()

      const deletedExiter = await plasma.methods.exits__exiter(exitID).call()

      const expected = '0x0000000000000000000000000000000000000000'
      assert.equal(deletedExiter, expected)
    })
    it('should allow challengeBeforeDeposit s', async () => {
      await plasma.methods.beginExit(0, 0, start, end).send({ value: 0, from: alice, gas: 4000000 })
      const exitID = exitNonce
      exitNonce++

      const coinID = 0 // anything in the deposit, 0-99
      await plasma.methods.challengeBeforeDeposit(
        exitID,
        coinID,
        end
      ).send()

      const deletedExiter = await plasma.methods.exits__exiter(exitID).call()

      const expected = '0x0000000000000000000000000000000000000000'
      assert.equal(deletedExiter, expected)
    })
    it('should allow challengeInvalidHistoryWithTransaction s and respondInvalidHistoryTransaction s', async () => {
      await plasma.methods.beginExit(0, 4, start, end).send({ value: 0, from: dave, gas: 4000000 })
      let exitID = exitNonce
      exitNonce++

      const transferIndex = 0 // will be first transfer for both chal and resp
      const coinID = 0 // could be any in deposit so [0,99]
      const unsignedA = new UnsignedTransaction(txA)
      await plasma.methods.challengeInvalidHistoryWithTransaction(
        exitID,
        coinID,
        transferIndex,
        '0x' + unsignedA.encoded,
        '0x' + blocks['A'].getTransactionProof(txA).encoded
      ).send({ value: 0, from: alice, gas: 4000000 })
      let chalID = chalNonce
      chalNonce++

      const chalCount = await plasma.methods.exits__challengeCount(exitID).call()
      assert.equal(chalCount, '1')

      const unsignedB = new UnsignedTransaction(txB)
      await plasma.methods.respondInvalidHistoryTransaction(
        chalID,
        transferIndex,
        '0x' + unsignedB.encoded,
        '0x' + blocks['B'].getTransactionProof(txB).encoded
      ).send()

      const newChalCount = await plasma.methods.exits__challengeCount(exitID).call()
      assert.equal(newChalCount, '0')

      const isOngoing = await plasma.methods.inclusionChallenges__ongoing(chalID).call()
      assert.equal(isOngoing, false)
    })
    it('should allow respondInvalidHistoryDeposit s', async () => {
      // create new deposit to respond with
      await plasma.methods.depositETH().send({ value: 100, from: alice, gas: 4000000 })

      // from txB extension above
      await plasma.methods.beginExit(0, 5, end, end + 100).send({ value: 0, from: alice, gas: 4000000 })
      let exitID = exitNonce
      exitNonce++

      const coinID = 100
      const transferIndex = 0 // only one transfer in these
      const unsigned = new UnsignedTransaction(txB)
      await plasma.methods.challengeInvalidHistoryWithTransaction(
        exitID,
        coinID,
        transferIndex,
        '0x' + unsigned.encoded,
        '0x' + blocks['B'].getTransactionProof(txB).encoded
      ).send({ value: 0, from: alice, gas: 4000000 })
      let chalID = chalNonce
      chalNonce++

      const chalCount = await plasma.methods.exits__challengeCount(exitID).call()
      assert.equal(chalCount, '1')

      const depositEnd = 200
      await plasma.methods.respondInvalidHistoryDeposit(
        chalID,
        depositEnd
      ).send()

      const newChalCount = await plasma.methods.exits__challengeCount(exitID).call()
      assert.equal(newChalCount, '0')

      const isOngoing = await plasma.methods.inclusionChallenges__ongoing(chalID).call()
      assert.equal(isOngoing, false)
    })
    it('should allow challengeInvalidHistoryWithDeposit s and responses', async () => {
      await plasma.methods.beginExit(0, 4, start, end).send({ value: 0, from: dave, gas: 4000000 })
      let exitID = exitNonce
      exitNonce++

      const transferIndex = 0 // will be first transfer for both chal and resp
      const coinID = 0 // could be any in deposit so [0,99]
      await plasma.methods.challengeInvalidHistoryWithDeposit(
        exitID,
        coinID,
        end
      ).send({ value: 0, from: alice, gas: 4000000 })
      let chalID = chalNonce
      chalNonce++

      const chalCount = await plasma.methods.exits__challengeCount(exitID).call()
      assert.equal(chalCount, '1')

      const unsigned = new UnsignedTransaction(txA)
      await plasma.methods.respondInvalidHistoryTransaction(
        chalID,
        transferIndex,
        '0x' + unsigned.encoded,
        '0x' + blocks['A'].getTransactionProof(txA).encoded
      ).send()

      const newChalCount = await plasma.methods.exits__challengeCount(exitID).call()
      assert.equal(newChalCount, '0')

      const isOngoing = await plasma.methods.inclusionChallenges__ongoing(chalID).call()
      assert.equal(isOngoing, false)
    })
  })
})

const getExit = (account, start, end) => {
  const parameters = web3.eth.abi.encodeParameters(['address'], [account.address])
  return {
    state: web3.eth.abi.encodeParameters(['bytes', 'address'], [parameters, web3.eth.accounts.wallet[0].address]),
    rangeStart: start,
    rangeEnd: end,
    exitHeight: 0,
    exitTime: 999
  }
}