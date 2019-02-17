var Math = artifacts.require("./Math.sol");
var ECRecovery = artifacts.require("./ECRecovery.sol");
var SimpleRangeTransferPredicate = artifacts.require("./SimpleRangeTransferPredicate.sol");
var SimpleMultiSigPredicate = artifacts.require("./SimpleMultiSigPredicate.sol");
var SimplePaymentChannelPredicate = artifacts.require("./SimplePaymentChannelPredicate.sol");
var Migrations = artifacts.require("./Migrations.sol");

module.exports = function(deployer) {
  deployer.deploy(Math);
  deployer.deploy(ECRecovery);
  deployer.deploy(SimpleRangeTransferPredicate);
  deployer.deploy(SimpleMultiSigPredicate);
  deployer.deploy(SimplePaymentChannelPredicate);
  deployer.deploy(Migrations);
};
