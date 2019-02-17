const plasmaChainCompiled = require('./compiled-contracts/plasma-chain.js')
const plasmaRegistryCompiled = require('./compiled-contracts/plasma-registry.js')
const erc20Compiled = require('./compiled-contracts/test-token.js')
const serializerCompiled = require('./compiled-contracts/serialization.js')
const utils = require('./utils.js')

module.exports = {
  plasmaChainCompiled,
  plasmaRegistryCompiled,
  erc20Compiled,
  serializerCompiled,
  utils
}
