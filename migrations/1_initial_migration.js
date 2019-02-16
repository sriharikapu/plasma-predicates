var Math = artifacts.require("./Math.sol");
var ECRecovery = artifacts.require("./ECRecovery.sol");
var SimpleRangeTransfer = artifacts.require("./SimpleRangeTransfer.sol");
var SimpleMultiSig = artifacts.require("./SimpleMultiSig.sol");
var SimpleStateChannel = artifacts.require("./SimpleStateChannel.sol");
var Migrations = artifacts.require("./Migrations.sol");

module.exports = function(deployer) {
  deployer.deploy(Math);
  deployer.deploy(ECRecovery);
  deployer.deploy(SimpleRangeTransfer);
  deployer.deploy(SimpleMultiSig);
  deployer.deploy(SimpleStateChannel);
  deployer.deploy(Migrations);
};
