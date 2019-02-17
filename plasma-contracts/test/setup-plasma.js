const ganache = require('ganache-cli')
const Web3 = require('web3')
const BigNum = require('bn.js')

const Transaction = require('plasma-utils').serialization.models.Transaction

const MAX_END = new BigNum('170141183460469231731687303715884105727', 10) // this is not the right max end for 16 bytes, but we're gonna leave it for now as vyper has a weird bug only supporting uint128 vals
const IMAGINARY_PRECEDING = MAX_END.add(new BigNum(1))

// const encoder = require('plasma-utils').encoder

// SETUP WEB3 AND GANACHE
const web3 = new Web3()
const ganacheAccounts = []
for (let i = 0; i < 5; i++) {
  const privateKey = Web3.utils.sha3(i.toString())
  ganacheAccounts.push({
    balance: '0x99999999991',
    secretKey: privateKey
  })
  web3.eth.accounts.wallet.add(privateKey)
}
// For all provider options, see: https://github.com/trufflesuite/ganache-cli#library
const providerOptions = { 'accounts': ganacheAccounts, 'locked': false, 'gasLimit': '0x996acfc0' } // , 'logger': console }//, 'debug': true }
web3.setProvider(ganache.provider(providerOptions))

async function mineBlock () {
  return new Promise((resolve, reject) => {
    web3.currentProvider.sendAsync({
      jsonrpc: '2.0',
      method: 'evm_mine',
      id: new Date().getTime()
    }, function (err, result) {
      if (err) {
        reject(err)
      }
      resolve(result)
    })
  })
}

async function mineNBlocks (n) {
  for (let i = 0; i < n; i++) {
    await mineBlock()
  }
  console.log('mined ' + n + ' empty blocks')
}

async function getCurrentChainSnapshot () {
  return new Promise((resolve, reject) => {
    web3.currentProvider.sendAsync({
      jsonrpc: '2.0',
      method: 'evm_snapshot',
      id: new Date().getTime()
    }, function (err, result) {
      if (err) {
        reject(err)
      }
      resolve(result)
    })
  })
}

async function revertToChainSnapshot (snapshot) { // eslint-disable-line no-unused-vars
  return new Promise((resolve, reject) => {
    web3.currentProvider.sendAsync({
      jsonrpc: '2.0',
      method: 'evm_revert',
      id: new Date().getTime(),
      params: [snapshot.result],
      external: true
    }, function (err, result) {
      if (err) {
        console.log(err)
        reject(err)
      }
      console.log('result: ', result)
      resolve(result)
    })
  })
}

/**
 * Returns a list of `n` sequential transactions.
 * @param {*} n Number of sequential transactions to return.
 * @return {*} A list of sequential transactions.
 */
const getSequentialTxs = (n) => {
  let txs = []
  for (let i = 0; i < n; i++) {
    txs[i] = new Transaction({
      block: 1,
      transfers: [
        {
          sender: web3.eth.accounts.wallet[0].address,
          recipient: web3.eth.accounts.wallet[1].address,
          token: 0,
          start: i * 20,
          end: (i + 0.5) * 20
        }
      ]
    })
  }
  return txs
}

let bytecode, abi, plasma, operatorSetup, freshContractSnapshot

async function setupPlasma () {
  const addr = web3.eth.accounts.wallet[0].address

  await require('../compile-contracts').compileContracts()


  const serializationContract = require('../compiled-contracts/serialization.js')
  const serBytecode = serializationContract.bytecode
  const serAbi = serializationContract.abi

  const serCt = new web3.eth.Contract(serAbi, addr, { from: addr, gas: 7000000, gasPrice: '3000' })
  const ser = await serCt.deploy({ data: serBytecode }).send()

  debugger

  const contract = require('../compiled-contracts/plasma-chain.js')
  bytecode = contract.bytecode
  abi = contract.abi


  const plasmaCt = new web3.eth.Contract(abi, addr, { from: addr, gas: 7000000, gasPrice: '3000' })
  
  const solidityHelperAddress = '0x1000000000000000000000000000000000000000'

  await mineBlock()
  // Now try to deploy
  plasma = await plasmaCt.deploy({ data: bytecode }).send() /* {
        from: addr,
        gas: 2500000,
        gasPrice: '300000'
    })
    */
  // const block = await web3.eth.getBlock('latest')
  // const deploymentTransaction = await web3.eth.getTransaction(block.transactions[0]) // eslint-disable-line no-unused-vars
  const weiDecimalOffset = 0 // so it'll be wei
  debugger
  operatorSetup = await plasma.methods.setup(web3.eth.accounts.wallet[0].address, weiDecimalOffset, ser._address, solidityHelperAddress).send()
  freshContractSnapshot = await getCurrentChainSnapshot()
  return [bytecode, abi, plasma, operatorSetup, freshContractSnapshot, ser]
}

let tokenBytecode, tokenAbi, token

async function setupToken () {
  const contract = require('../compiled-contracts/test-token.js')
  tokenBytecode = contract.bytecode
  tokenAbi = contract.abi

  const addr = web3.eth.accounts.wallet[1].address

  const tokenCt = new web3.eth.Contract(tokenAbi, addr, { from: addr, gas: 6500000, gasPrice: '3000' })

  await mineBlock()
  const name = asBytes32('BenCoin')
  const ticker = asBytes32('BEN')
  const decimals = 5
  const totSupply = 1000
  // Now try to deploy
  token = await tokenCt.deploy(
    {
      arguments: [
        name,
        ticker,
        decimals,
        totSupply
      ],
      data: tokenBytecode
    }
  ).send({ from: web3.eth.accounts.wallet[1].address }) // give all initial balance to alice
  freshTokenSnapshot = await getCurrentChainSnapshot()
  return [tokenBytecode, tokenAbi, token, freshTokenSnapshot]
}

// pads a string's utf8 byte representation to 32 bytes, as string '0x' + ...
function asBytes32 (string) {
  var utf8 = stringToUtf8ByteArray(string)
  const remainingNumBytes = 32 - utf8.length
  let pad = []
  for (let i = 0; i < remainingNumBytes; i++) { pad.push(0) }
  return '0x' + new BigNum(utf8.concat(pad)).toString('hex', 64)
}

// modified from https://github.com/google/closure-library/blob/e877b1eac410c0d842bcda118689759512e0e26f/closure/goog/crypt/crypt.js
function stringToUtf8ByteArray (str) {
  // TODO(user): Use native implementations if/when available
  let out = []
  let p = 0
  for (let i = 0; i < str.length; i++) {
    let c = str.charCodeAt(i)
    if (c < 128) {
      out[p++] = c
    } else if (c < 2048) {
      out[p++] = (c >> 6) | 192
      out[p++] = (c & 63) | 128
    } else if (
      ((c & 0xFC00) === 0xD800) && (i + 1) < str.length &&
      ((str.charCodeAt(i + 1) & 0xFC00) === 0xDC00)) {
      // Surrogate Pair
      c = 0x10000 + ((c & 0x03FF) << 10) + (str.charCodeAt(++i) & 0x03FF)
      out[p++] = (c >> 18) | 240
      out[p++] = ((c >> 12) & 63) | 128
      out[p++] = ((c >> 6) & 63) | 128
      out[p++] = (c & 63) | 128
    } else {
      out[p++] = (c >> 12) | 224
      out[p++] = ((c >> 6) & 63) | 128
      out[p++] = (c & 63) | 128
    }
  }
  return out
}

module.exports = {
  getCurrentChainSnapshot,
  revertToChainSnapshot,
  MAX_END,
  IMAGINARY_PRECEDING,
  web3,
  mineBlock,
  mineNBlocks,
  getSequentialTxs,
  setupPlasma,
  setupToken,
  operatorSetup
}
