const fs = require('fs')
const compilation = require('./utils.js').contracts
const compilePlasmaChainContract = compilation.compilePlasmaChainContract
const compileSerializationContract = compilation.compileSerializationContract
const compilePlasmaRegistryContract = compilation.compilePlasmaRegistryContract
const compileTokenContract = compilation.compileTokenContract

async function compileContracts () {
  let plasmaChainBytecode, plasmaChainAbi
  [plasmaChainBytecode, plasmaChainAbi] = await compilePlasmaChainContract()

  let serializationBytecode, serializationAbi
  [serializationBytecode, serializationAbi] = await compileSerializationContract()

  let plasmaRegistryBytecode, plasmaRegistryAbi
  [plasmaRegistryBytecode, plasmaRegistryAbi] = await compilePlasmaRegistryContract()

  let tokenBytecode, tokenAbi
  [tokenBytecode, tokenAbi] = await compileTokenContract()

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

  console.log('Compiled contracts! Saving them to ./compiled-contracts')
  await fs.writeFileSync('compiled-contracts/plasma-chain.js', plasmaChainJS)
  await fs.writeFileSync('compiled-contracts/serialization.js', serializationJS)
  await fs.writeFileSync('compiled-contracts/plasma-registry.js', plasmaRegistryJS)
  await fs.writeFileSync('compiled-contracts/test-token.js', tokenJS)
}

module.exports = {
  compileContracts: compileContracts
}
