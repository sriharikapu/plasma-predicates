pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import '../IPredicate.sol';
import '../../libraries/BasicChecks.sol';
import './PaymentChannel.sol';

contract SimplePaymentChannelPredicate is IPredicate {
    /*
     * Structs
     */

    struct StateData {
        address[] owners;
    }

    struct Witness {
        uint256 rangeStart;
        uint256 rangeEnd;
        bytes[] signatures;
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

        // Check transaction signatures.
        bool validSignatures = BasicChecks.checkSignatures(
            witness.rangeStart,
            witness.rangeEnd,
            _exit.exitHeight,
            witness.signatures,
            state.owners,
            state.owners.length
        );

        // Check transaction bounds.
        bool validBounds = BasicChecks.checkBounds(
            _exit.rangeStart,
            _exit.rangeEnd,
            witness.rangeStart,
            witness.rangeEnd
        );

        // TODO: Check inclusion.

        return validSignatures && validBounds;
    }

    function canStartExit(
        Exit memory _exit,
        bytes memory _witness
    ) public returns (bool) {
        StateData memory state = bytesToStateData(_exit.state);

        // Check valid transaction sender.
        bool validSender = BasicChecks.checkOwner(tx.origin, state.owners);

        return validSender;
    }

    function finalizeExit(
        Exit memory _exit,
        bytes memory _witness
    ) public payable {
        StateData memory state = bytesToStateData(_exit.state);
        
        PaymentChannel channel = (new PaymentChannel).value(msg.value)(state.owners);
    }


    /*
     * Internal functions
     */

    function bytesToWitness(
        bytes memory _witness
    ) internal pure returns (Witness memory) {
        (uint256 rangeStart, uint256 rangeEnd, bytes[] memory signatures) = abi.decode(_witness, (uint256, uint256, bytes[]));
        return Witness(rangeStart, rangeEnd, signatures);
    }

    function bytesToStateData(
        bytes memory _state
    ) internal pure returns (StateData memory) {
        (bytes memory parameters, ) = abi.decode(_state, (bytes, address));
        (address[] memory owners) = abi.decode(parameters, (address[]));
        return StateData(owners);
    }
}
