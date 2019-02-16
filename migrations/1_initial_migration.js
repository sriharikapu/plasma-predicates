var Math = artifacts.require("./Math.sol");
var ECRecovery = artifacts.require("./ECRecovery.sol");
var SimpleRangeTransfer = artifacts.require("./SimpleRangeTransfer.sol");
var Migrations = artifacts.require("./Migrations.sol");

module.exports = function(deployer) {
  deployer.deploy(Math);
  deployer.deploy(ECRecovery);
  deployer.deploy(SimpleRangeTransfer);
  deployer.deploy(Migrations);
};
