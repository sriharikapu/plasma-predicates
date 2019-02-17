const EthCrypto = require('eth-crypto')
const { AbiCoder } = require('web3-eth-abi')
const abi = new AbiCoder()

const checkSignature = (state, witness, signature, owner) => {
  const message = abi.encodeParameters(['uint256', 'uint256', 'uint256'], [witness.rangeStart, witness.rangeEnd, state.blockHeight])
  const messageHash = EthCrypto.hash.keccak256(message)
  return (EthCrypto.recover(signature, messageHash) === owner)
}

const checkSignatures = (state, witness, signatures, owners, threshold) => {
  let validSignatures = 0
  signatures.forEach((_, i) => {
    const validSignature = checkSignature(state, witness, signatures[i], owners[i])
    if (validSignature) validSignatures++
  })
  return (validSignatures >= threshold)
}

module.exports = {
  checkSignature,
  checkSignatures
}

