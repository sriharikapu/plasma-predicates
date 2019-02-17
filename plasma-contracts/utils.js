const util = require('util')
const exec = util.promisify(require('child_process').exec)
const solc = require('solc')
const fs = require('fs')

// Helper functions for compiling the Vyper contracts
async function compileVyper (path) {
  const bytecodeOutput = await exec('vyper ' + path + ' -f bytecode')
  const abiOutput = await exec('vyper ' + path + ' -f abi')
  // Return both of the output's stdout without the last character which is \n
  return [ bytecodeOutput.stdout.slice(0, -1), abiOutput.stdout.slice(0, -1) ]
}

async function compilePlasmaChainContract () {
  return compileVyper('./contracts/PlasmaChain.vy')
}

async function compileSerializationContract () {
  return compileVyper('./contracts/Serialization.vy')
}

async function compilePlasmaRegistryContract () {
  return compileVyper('./contracts/PlasmaRegistry.vy')
}

async function compileTokenContract () {
  return compileVyper('./contracts/test-contracts/ERC20.vy')
}

async function compileAbiSerializeContract () {

  const solString = fs.readFileSync('./contracts/VyperHelper.sol', 'utf8')
  const input = {
    language: 'Solidity',
    sources: {
      'VyperHelper.sol': {
        content: solString
      }
    },
    settings: {
      outputSelection: {
        '*': {
          '*': [ '*' ]
        }
      }
    }
}

  var output = JSON.parse(solc.compile(JSON.stringify(input)))

  const bytecode = '0x' + output.contracts['VyperHelper.sol']['VyperHelper'].evm.bytecode.object
  const abi = output.contracts['VyperHelper.sol']['VyperHelper'].abi


  //const output = solc.compile(input.toString(), 1)
  //const bytecode = output.contracts['Token'].bytecode
  //const abi = JSON.parse(output.contracts['Token'].interface)
  return [bytecode, JSON.stringify(abi)]
}

async function compileRangeTransferPredicate () {
  const transferString = fs.readFileSync('./contracts/predicate-contracts/range-transfer/SimpleRangeTransferPredicate.sol', 'utf8')
  const iPredicateString = fs.readFileSync('./contracts/predicate-contracts/IPredicate.sol', 'utf8')
  const basicChecksString = fs.readFileSync('./contracts/predicate-contracts/BasicChecks.sol', 'utf8')
  const ECRString = fs.readFileSync('./contracts/predicate-contracts/ECRecovery.sol', 'utf8')
  const mathString = fs.readFileSync('./contracts/predicate-contracts/Math.sol', 'utf8')
  const input = {
    language: 'Solidity',
    sources: {
      'SimpleRangeTransferPredicate.sol': {
        content: transferString
      },
      'IPredicate.sol': {
        content: iPredicateString
      },
      'BasicChecks.sol': {
        content: basicChecksString
      },
      'ECRecovery.sol': {
        content: ECRString
      },
      'Math.sol': {
        content: mathString
      },
    },
    settings: {
      outputSelection: {
        '*': {
          '*': [ '*' ]
        }
      }
    }
}

  var output = JSON.parse(solc.compile(JSON.stringify(input)))

  const bytecode = '0x' + output.contracts['SimpleRangeTransferPredicate.sol']['SimpleRangeTransferPredicate'].evm.bytecode.object
  const abi = output.contracts['SimpleRangeTransferPredicate.sol']['SimpleRangeTransferPredicate'].abi



  //const output = solc.compile(input.toString(), 1)
  //const bytecode = output.contracts['Token'].bytecode
  //const abi = JSON.parse(output.contracts['Token'].interface)
  return [bytecode, JSON.stringify(abi)]
}

module.exports = {
  contracts: {
    compileVyper,
    compilePlasmaChainContract,
    compileSerializationContract,
    compilePlasmaRegistryContract,
    compileTokenContract,
    compileAbiSerializeContract,
    compileRangeTransferPredicate
  }
}
