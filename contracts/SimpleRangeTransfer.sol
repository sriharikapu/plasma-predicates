pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import './IPredicate.sol';
import './ECRecovery.sol';
import './Math.sol';

contract SimpleRangeTransfer is IPredicate {
    /*
     * Structs
     */

    struct StateData {
        address owner;
    }

    struct Witness {
        uint256 rangeStart;
        uint256 rangeEnd;
        bytes signature;
    }


    /*
     * Public functions
     */

    function canCancel(
        Exit memory _exit,
        bytes memory _witness
    ) public returns (bool) {
        Witness memory witness = bytesToWitness(_witness);
        StateData memory state = bytesToStateData(_exit.state);

        // Check transaction signature.
        bytes memory message = abi.encode(witness.rangeStart, witness.rangeEnd, _exit.exitHeight);
        bytes32 messageHash = keccak256(message);
        bool validSignature = ECRecovery.recover(messageHash, witness.signature) == state.owner;

        // Check transaction bounds.
        bool validBounds = Math.max(witness.rangeStart, _exit.rangeStart) < Math.min(witness.rangeEnd, _exit.rangeEnd);

        // TODO: Check inclusion.

        return validSignature && validBounds;
    }

    function canStartExit(
        Exit memory _exit,
        bytes memory _witness
    ) public returns (bool) {
        StateData memory state = bytesToStateData(_exit.state);

        // Check valid transaction sender.
        bool validSender = (tx.origin == state.owner);

        return validSender;
    }

    function finalizeExit(
        Exit memory _exit,
        bytes memory _witness
    ) public payable {
        StateData memory state = bytesToStateData(_exit.state);
        
        // Forward all money to the owner.
        address payable owner = address(uint160(state.owner));
        owner.transfer(msg.value);
    }


    /*
     * Internal functions
     */

    function bytesToWitness(
        bytes memory _witness
    ) internal pure returns (Witness memory) {
        (uint256 rangeStart, uint256 rangeEnd, bytes memory signature) = abi.decode(_witness, (uint256, uint256, bytes));
        return Witness(
            rangeStart,
            rangeEnd,
            signature
        );
    }

    function bytesToStateData(
        bytes memory _state
    ) internal pure returns (StateData memory) {
        (bytes memory parameters, ) = abi.decode(_state, (bytes, address));
        address owner = abi.decode(parameters, (address));
        return StateData(
            owner
        );
    }
}
