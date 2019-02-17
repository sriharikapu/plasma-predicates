pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "../../libraries/ECRecovery.sol";

contract PaymentChannel {
    address[] public participants;

    constructor(address[] memory _participants) public payable {
        participants = _participants;
    }

    function close(bytes[] memory _signatures, bytes memory _state) public view {
        for (uint i = 0; i < participants.length; i++) {
            bytes32 message = keccak256(_state);
            bool validSignature = (ECRecovery.recover(message, _signatures[i]) == participants[i]);
            require(validSignature, "Invalid signature.");
        }

        // TODO: Send money out to the correct parties.
    }
}
