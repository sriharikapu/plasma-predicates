/* eslint-env mocha */
/* eslint-disable no-unused-expressions */

/* NOTE: filename has a 0 appended so that mocha loads this first,
so that contract deployment is only done once.  If you create a new
test, do it with a before() as in other files, not this one */

const chai = require('chai')
const expect = chai.expect
const assert = chai.assert

const plasmaUtils = require('plasma-utils')
const PlasmaMerkleSumTree = plasmaUtils.PlasmaMerkleSumTree
const genSequentialTXs = plasmaUtils.utils.getSequentialTxs
const models = plasmaUtils.serialization.models
const UnsignedTransaction = models.UnsignedTransaction
const SignedTransaction = models.SignedTransaction

const setup = require('./setup-plasma')
const web3 = setup.web3
const CHALLENGE_PERIOD = 20

const BigNum = require('bn.js')

describe('ERC20 Token Support', () => {
  const [operator, alice, bob, carol, dave] = [ // eslint-disable-line no-unused-vars
    web3.eth.accounts.wallet[0].address,
    web3.eth.accounts.wallet[1].address,
    web3.eth.accounts.wallet[2].address,
    web3.eth.accounts.wallet[3].address,
    web3.eth.accounts.wallet[4].address
  ]

  const benTokenType = 1
  const benCoinDenomination = '0' // --> ERC20 bal = plasma balance * 10^3
  let listingNonce = 1
  let exitNonce = 0

  let bytecode, abi, plasma, operatorSetup, freshContractSnapshot, freshTokenSnapshot, serializer // eslint-disable-line no-unused-vars
  let tokenBytecode, tokenAbi, token
  // BEGIN SETUP
  before(async () => {
    // setup ganache, deploy, etc.
    [
      bytecode, abi, plasma, operatorSetup, freshContractSnapshot, serializer
    ] = await setup.setupPlasma()
    ;
    [
      tokenBytecode, tokenAbi, token, freshTokenSnapshot
    ] = await setup.setupToken()
  })

  describe('Non-ETH Listings, Deposits, and Exits', () => {
    it('Should have compiled the plasma contract without errors', async () => {
      expect(abi).to.exist
      expect(bytecode).to.exist
      expect(plasma).to.exist
      expect(web3).to.exist
    })
    it('Should have setup() the contract for without errors', async () => {
      expect(operatorSetup).to.exist
    })
    it('Should have compiled the plasma contract without errors', async () => {
      expect(tokenAbi).to.exist
      expect(tokenBytecode).to.exist
      expect(token).to.exist
    })
    it('should allow anyone to list a new token', async () => {
      await plasma.methods.listToken(token._address, benCoinDenomination).send()

      const listingAddress = await plasma.methods.listings__contractAddress(listingNonce).call()
      const listingDenomination = await plasma.methods.listings__decimalOffset(listingNonce).call()

      expect(listingAddress).to.equal(token._address)
      expect(listingDenomination).to.equal(benCoinDenomination)
    })
    const aliceDepositSize = '100'
    const aliceNumPlasmaCoins = aliceDepositSize * Math.pow(10, benCoinDenomination)
    it('should allow allice to approve and deposit', async () => {
      await token.methods.approve(plasma._address, aliceDepositSize).send({ from: alice })

      await plasma.methods.depositERC20(token._address, aliceDepositSize).send({ from: alice })

      const newContractBalance = await token.methods.balanceOf(plasma._address).call()
      expect(newContractBalance).to.equal(aliceDepositSize)

      const newDepositStart = await plasma.methods.deposits__untypedStart(1, aliceNumPlasmaCoins).call()
      expect(newDepositStart).to.equal('0') // first deposit tokentype 1 ^ should equal 0 since it was the first

      const newDepositer = await plasma.methods.deposits__depositer(1, aliceNumPlasmaCoins).call()
      expect(newDepositer).to.equal(alice)
    })
    it('should allow bob to exit the ERC20s if uncontested', async () => {
      await plasma.methods.beginExit(benTokenType, 0, 0, aliceNumPlasmaCoins).send({ from: bob })
      const exitID = exitNonce
      exitNonce++

      await setup.mineNBlocks(CHALLENGE_PERIOD)

      await plasma.methods.finalizeExit(exitID, aliceNumPlasmaCoins).send()

      const newPlasmaBalance = await token.methods.balanceOf(plasma._address).call()
      const newBobBalance = await token.methods.balanceOf(bob).call()

      expect(newBobBalance).to.equal(aliceDepositSize)
      expect(newPlasmaBalance).to.equal('0')
    })
  })
  describe('Exit Games for non-ETH tokens', () => {
    const [tokenType, start, end] = [1, 0, 100]
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
          token: tokenType,
          start: start,
          end: end
        }
      ]
    })
    const txA = new SignedTransaction({
      ...txAUnsigned,
      ...{ signatures: [plasmaUtils.utils.sign(txAUnsigned.hash, web3.eth.accounts.wallet[1].privateKey)] }
    })
    const txBUnsigned = new UnsignedTransaction({
      block: blockNumB,
      transfers: [
        {
          sender: bob,
          recipient: carol,
          token: tokenType,
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
          token: tokenType,
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
    const otherTXs = genSequentialTXs(300).slice(299)
    otherTXs.forEach((tx) => { tx.transfers[0].token = new BigNum(1) })
    const blocks = {
      A: new PlasmaMerkleSumTree([txA].concat(otherTXs)),
      B: new PlasmaMerkleSumTree([txB].concat(otherTXs)),
      C: new PlasmaMerkleSumTree([txC].concat(otherTXs))
    }

    let chalNonce = 0
    let exitNonce = 0
    const dummyBlockHash = '0x0000000000000000000000000000000000000000000000000000000000000000'
    before(async function () {
      await setup.revertToChainSnapshot(freshTokenSnapshot)
      freshContractSnapshot = await setup.getCurrentChainSnapshot() // weird bug where ganache crashes if you load the same snapshot twice, so gotta "reset" it every time it's used.
      await plasma.methods.submitBlock(dummyBlockHash).send({ value: 0, from: operator, gas: 4000000 }).catch((error) => { console.log('send callback failed: ', error) })
      await plasma.methods.submitBlock(dummyBlockHash).send({ value: 0, from: operator, gas: 4000000 }).catch((error) => { console.log('send callback failed: ', error) })

      await plasma.methods.listToken(token._address, benCoinDenomination).send()
      await token.methods.approve(plasma._address, end).send({ from: alice })
      await plasma.methods.depositERC20(token._address, end).send({ from: alice, gas: 4000000 })

      await plasma.methods.submitBlock('0x' + blocks['A'].root().hash).send({ value: 0, from: operator, gas: 4000000 })
      await plasma.methods.submitBlock('0x' + blocks['B'].root().hash).send({ value: 0, from: operator, gas: 4000000 })
      await plasma.methods.submitBlock('0x' + blocks['C'].root().hash).send({ value: 0, from: operator, gas: 4000000 })
    })
    it('should allow inclusionChallenges and respondTransactionInclusion', async () => {
      await plasma.methods.beginExit(tokenType, 5, start, end).send({ value: 0, from: dave, gas: 4000000 })
      let exitID = exitNonce // this will be 0 since it's the first exit
      exitNonce++

      await plasma.methods.challengeInclusion(exitID).send({ value: 0, from: alice, gas: 4000000 })
      let chalID = chalNonce // remember, the challenge nonce only counts respondable challenges (inv history and inclusion)
      chalNonce++

      const chalCount = await plasma.methods.exits__challengeCount(exitID).call()
      assert.equal(chalCount, '1')

      const transferIndex = 0
      const unsigned = new UnsignedTransaction(txC)
      await plasma.methods.respondTransactionInclusion(
        chalID,
        transferIndex,
        '0x' + unsigned.encoded,
        '0x' + blocks['C'].getTransactionProof(txC).encoded
      ).send()

      const newChalCount = await plasma.methods.exits__challengeCount(exitID).call()
      assert.equal(newChalCount, '0')

      const isOngoing = await plasma.methods.inclusionChallenges__ongoing(chalID).call()
      assert.equal(isOngoing, false)
    })
    it('should allow respondDepositInclusion s', async () => {
      await plasma.methods.beginExit(tokenType, 2, start, end).send({ value: 0, from: alice, gas: 4000000 })
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
    it('should allow Spent Coin Challenges to cancel exits', async () => {
      // have Bob exit even though he sent to Carol
      await plasma.methods.beginExit(tokenType, 3, start, end).send({ value: 0, from: carol, gas: 4000000 })
      const exitID = exitNonce
      exitNonce++

      const coinID = '0x00000001000000000000000000000000'
      const transferIndex = 0 // only one transfer in these
      const chalTX = txC
      const unsigned = new UnsignedTransaction(chalTX)
      await plasma.methods.challengeSpentCoin(
        exitID,
        coinID,
        transferIndex,
        '0x' + unsigned.encoded,
        '0x' + blocks['C'].getTransactionProof(chalTX).encoded
      ).send()

      const deletedExiter = await plasma.methods.exits__exiter(exitID).call()

      const expected = '0x0000000000000000000000000000000000000000'
      assert.equal(deletedExiter, expected)
    })
    it('should allow challengeBeforeDeposit s', async () => {
      await plasma.methods.beginExit(tokenType, 0, start, end).send({ value: 0, from: alice, gas: 4000000 })
      const exitID = exitNonce
      exitNonce++

      const coinID = '0x00000001000000000000000000000000' // anything in the deposit, 0-99, typed
      
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
      await plasma.methods.beginExit(tokenType, 4, start, end).send({ value: 0, from: dave, gas: 4000000 })
      let exitID = exitNonce
      exitNonce++

      const transferIndex = 0 // will be first transfer for both chal and resp
      const coinID = '0x00000001000000000000000000000000' // anything in the deposit, 0-99, typed
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
      await token.methods.approve(plasma._address, end).send({ from: alice })
      await plasma.methods.depositERC20(token._address, 100).send({ from: alice, gas: 4000000 })

      // from txB extension above
      await plasma.methods.beginExit(tokenType, 5, end, end + 100).send({ value: 0, from: alice, gas: 4000000 })
      let exitID = exitNonce
      exitNonce++

      const coinID = '0x00000001000000000000000000000064'
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
      await plasma.methods.beginExit(tokenType, 4, start, end).send({ value: 0, from: dave, gas: 4000000 })
      let exitID = exitNonce
      exitNonce++

      const transferIndex = 0 // will be first transfer for both chal and resp
      const coinID = '0x00000001000000000000000000000000'
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
