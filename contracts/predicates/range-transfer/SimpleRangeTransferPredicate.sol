pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import '../IPredicate.sol';
import '../../libraries/BasicChecks.sol';

contract SimpleRangeTransferPredicate is IPredicate {
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
    ) public view returns (bool) {
        Witness memory witness = bytesToWitness(_witness);
        StateData memory state = bytesToStateData(_exit.state);

        // Check transaction signature.
        bool validSignature = BasicChecks.checkSignature(
            witness.rangeStart,
            witness.rangeEnd,
            _exit.exitHeight,
            witness.signature,
            state.owner
        );

        // Check transaction bounds.
        bool validBounds = BasicChecks.checkBounds(
            _exit.rangeStart,
            _exit.rangeEnd,
            witness.rangeStart,
            witness.rangeEnd
        );

        // TODO: Check inclusion.

        return validSignature && validBounds;
    }

    function canStartExit(
        Exit memory _exit,
        bytes memory _witness
    ) public view returns (bool) {
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
        return Witness(rangeStart, rangeEnd, signature);
    }

    function bytesToStateData(
        bytes memory _state
    ) internal pure returns (StateData memory) {
        (bytes memory parameters, ) = abi.decode(_state, (bytes, address));
        address owner = abi.decode(parameters, (address));
        return StateData(owner);
    }
}
