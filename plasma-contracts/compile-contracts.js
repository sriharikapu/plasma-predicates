const fs = require('fs')
const compilation = require('./utils.js').contracts
const compilePlasmaChainContract = compilation.compilePlasmaChainContract
const compileSerializationContract = compilation.compileSerializationContract
const compilePlasmaRegistryContract = compilation.compilePlasmaRegistryContract
const compileTokenContract = compilation.compileTokenContract
const compileAbiSerializeContract = compilation.compileAbiSerializeContract
const compileRangeTransferPredicate = compilation.compileRangeTransferPredicate

async function compileContracts () {
  let plasmaChainBytecode, plasmaChainAbi
  [plasmaChainBytecode, plasmaChainAbi] = await compilePlasmaChainContract()

  let serializationBytecode, serializationAbi
  [serializationBytecode, serializationAbi] = await compileSerializationContract()

  let plasmaRegistryBytecode, plasmaRegistryAbi
  [plasmaRegistryBytecode, plasmaRegistryAbi] = await compilePlasmaRegistryContract()

  let tokenBytecode, tokenAbi
  [tokenBytecode, tokenAbi] = await compileTokenContract()

  let abiSerializeBytecode, abiSerializeAbi
  [abiSerializeBytecode, abiSerializeAbi] = await compileAbiSerializeContract()

  // Create JS file for easy imports of the Plasma chain binary & abi
  const plasmaChainJS = `
module.exports = {
  bytecode: '${plasmaChainBytecode}',
  abi: JSON.parse('${plasmaChainAbi}')
}
`
  const serializationJS = `
module.exports = {
  bytecode: '${serializationBytecode}',
  abi: JSON.parse('${serializationAbi}')
}
`
  const plasmaRegistryJS = `
module.exports = {
  bytecode: '${plasmaRegistryBytecode}',
  abi: JSON.parse('${plasmaRegistryAbi}')
}
`
  const tokenJS = `
module.exports = {
  bytecode: '${tokenBytecode}',
  abi: JSON.parse('${tokenAbi}')
}
`
const abiSeralizeJS = `
module.exports = {
  bytecode: '${abiSerializeBytecode}',
  abi: JSON.parse('${abiSerializeAbi}')
}
`

  console.log('Compiled contracts! Saving them to ./compiled-contracts')
  await fs.writeFileSync('compiled-contracts/plasma-chain.js', plasmaChainJS)
  await fs.writeFileSync('compiled-contracts/serialization.js', serializationJS)
  await fs.writeFileSync('compiled-contracts/plasma-registry.js', plasmaRegistryJS)
  await fs.writeFileSync('compiled-contracts/test-token.js', tokenJS)
  await fs.writeFileSync('compiled-contracts/abi-serialize.js', abiSeralizeJS)
}

module.exports = {
  compileContracts: compileContracts
}
