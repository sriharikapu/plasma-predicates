const Web3 = require('web3');
const EthCrypto = require('eth-crypto');
const LightningPredicate = artifacts.require('LightningPredicate')

const web3 = new Web3('http://localhost:8545')
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

const createMultiSigScript = (account1, account2) => {
  return {
    sigil: '02',
    value: '000000000000000000000000000000000000000000000000000000000000ffff',
    script: account1.address.slice(2).toLowerCase() + account2.address.slice(2).toLowerCase(),
    inputsHash: '0000000000000000000000000000000000000000000000000000000000000000',
    inputIndex: '0000000000000000000000000000000000000000000000000000000000000000'
  }
}

const encodeScript = (script) => {
  return '0x' + script.value + script.sigil + script.script + script.inputsHash + script.inputIndex
}

const takeScript = (script) => {
  return '0x' + script.value + script.sigil + script.script
}

const getOutputId = (output) => {
  const message = '0x' + output.inputsHash + output.sigil + output.script + output.value + output.inputIndex
  return web3.utils.sha3(message)
}

const getOutputSigHash = (output, txtype, outscripts) => {
  const outputId = getOutputId(output)
  return web3.utils.sha3(outputId + txtype + outscripts)
}

const getMultiSigExitParameters = (account1, account2) => {
  const multiSigScript = createMultiSigScript(account1, account2)
  const encodedScript = encodeScript(multiSigScript)
  return web3.eth.abi.encodeParameters(['bytes[]'], [[encodedScript]])
}

const getMultiSigWitnesses = (account1, account2, outscripts) => {
  const multiSigScript = createMultiSigScript(account1, account2)
  const txtype = '00'
  const sighash = getOutputSigHash(multiSigScript, txtype, outscripts.slice(2))
  const sigA = EthCrypto.sign(account1.privateKey, sighash)
  const sigB = EthCrypto.sign(account2.privateKey, sighash)
  const witness = txtype + sigA.slice(2) + sigB.slice(2)
  const len = web3.utils.padLeft(web3.utils.numberToHex(witness.length / 2), 32)
  return len + witness
}

const getMultiSigWitness = (account1, account2, start, end) => {
  const outscripts = takeScript(createMultiSigScript(account1, account2))
  const witnesses = getMultiSigWitnesses(account1, account2, outscripts)
  return web3.eth.abi.encodeParameters(['uint256', 'uint256', 'bytes', 'bytes'], [start, end, witnesses, outscripts])
}

const getExit = (parameters, start, end) => {
  return {
    state: web3.eth.abi.encodeParameters(['bytes', 'address'], [parameters, ZERO_ADDRESS]),
    rangeStart: start,
    rangeEnd: end,
    exitHeight: 0,
    exitTime: 999
  }
}

const createAccount = (n) => {
  return web3.eth.accounts.privateKeyToAccount(web3.utils.padLeft(n, 64))
}

contract('LightningPredicate', () => {
  const account1 = createAccount('0x01')
  const account2 = createAccount('0x02')

  describe('canCancel', () => {
    it('should cancel a valid spend', async () => {
      const instance = await LightningPredicate.deployed()

      const exitParams = getMultiSigExitParameters(account1, account2)
      const exit = getExit(exitParams, 0, 100)

      const witness = getMultiSigWitness(account1, account2, 0, 100)

      const canCancel = await instance.canCancel(exit, witness)
      assert.isTrue(canCancel)
    })
  })
})
