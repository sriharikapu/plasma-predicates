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

    function checkSignatures(
        uint256 _rangeStart,
        uint256 _rangeEnd,
        uint256 _exitHeight,
        bytes[] memory _signatures,
        address[] memory _owners,
        uint256 threshold
    ) internal pure returns (bool) {
        uint256 signatures = 0;
        for (uint256 i = 0; i < _signatures.length; i++) {
            bool validSignature = checkSignature(
                _rangeStart,
                _rangeEnd,
                _exitHeight,
                _signatures[i],
                _owners[i]
            );
            if (validSignature) {
                signatures++;
            }
        }
        return (signatures >= threshold);
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
