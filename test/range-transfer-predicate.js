const Web3 = require('web3');
const EthCrypto = require('eth-crypto');
const SimpleRangeTransferPredicate = artifacts.require('SimpleRangeTransferPredicate')

const web3 = new Web3('http://localhost:8545')
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

const getExit = (account, start, end) => {
  const parameters = web3.eth.abi.encodeParameters(['address'], [account.address])
  return {
    state: web3.eth.abi.encodeParameters(['bytes', 'address'], [parameters, ZERO_ADDRESS]),
    rangeStart: start,
    rangeEnd: end,
    exitHeight: 0,
    exitTime: 999
  }
}

const getWitness = async (account, start, end) => {
  const message = web3.eth.abi.encodeParameters(['uint256', 'uint256', 'uint256'], [start, end, 0])
  const messageHash = web3.utils.sha3(message)
  const sig = EthCrypto.sign(account.privateKey, messageHash)
  return web3.eth.abi.encodeParameters(['uint256', 'uint256', 'bytes'], [start, end, sig])
}

const createAccount = () => {
  return web3.eth.accounts.create()
}

contract('SimpleRangeTransferPredicate', () => {
  const account1 = createAccount()
  const account2 = createAccount()

  describe('canCancel', () => {
    it('should cancel a spend over the whole range', async () => {
      const instance = await SimpleRangeTransferPredicate.deployed()
      const exit = getExit(account1, 0, 100)
      const witness = await getWitness(account1, 0, 100)
      const canCancel = await instance.canCancel(exit, witness)
      assert.isTrue(canCancel)
    })

    it('should cancel a spend over part of the range', async () => {
      const instance = await SimpleRangeTransferPredicate.deployed()
      const exit = getExit(account1, 0, 100)
      const witness = await getWitness(account1, 25, 75)
      const canCancel = await instance.canCancel(exit, witness)
      assert.isTrue(canCancel)
    })

    it('should cancel a spend that intersects the range', async () => {
      const instance = await SimpleRangeTransferPredicate.deployed()
      const exit = getExit(account1, 0, 100)
      const witness = await getWitness(account1, 75, 125)
      const canCancel = await instance.canCancel(exit, witness)
      assert.isTrue(canCancel)
    })

    it('should not cancel a spend with an invalid signature', async () => {
      const instance = await SimpleRangeTransferPredicate.deployed()
      const exit = getExit(account1, 0, 100)
      const witness = await getWitness(account2, 0, 100)
      const canCancel = await instance.canCancel(exit, witness)
      assert.isFalse(canCancel)
    })
  })
})
