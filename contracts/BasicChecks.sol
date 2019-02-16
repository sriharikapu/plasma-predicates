pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import './ECRecovery.sol';
import './Math.sol';

library BasicChecks {
    function checkSignature(
        uint256 _rangeStart,
        uint256 _rangeEnd,
        uint256 _exitHeight,
        bytes memory _signature,
        address _owner
    ) internal pure returns (bool) {
        bytes memory message = abi.encode(_rangeStart, _rangeEnd, _exitHeight);
        bytes32 messageHash = keccak256(message);
        return (ECRecovery.recover(messageHash, _signature) == _owner);
    }

    function checkBounds(
        uint256 _exitStart,
        uint256 _exitEnd,
        uint256 _witnessStart,
        uint256 _witnessEnd
    ) internal pure returns (bool) {
        return (Math.max(_exitStart, _witnessStart) < Math.min(_exitEnd, _witnessEnd));
    }
}
