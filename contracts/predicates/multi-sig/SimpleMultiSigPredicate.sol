pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "../IPredicate.sol";
import "../../libraries/BasicChecks.sol";
import "./MultiSig.sol";

contract SimpleMultiSigPredicate is IPredicate {
    /*
     * Structs
     */

    struct StateData {
        address[] owners;
        uint256 threshold;
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
    ) public view returns (bool) {
        Witness memory witness = bytesToWitness(_witness);
        StateData memory state = bytesToStateData(_exit.state);

        // Check transaction signatures.
        bool validSignatures = BasicChecks.checkSignatures(
            witness.rangeStart,
            witness.rangeEnd,
            _exit.exitHeight,
            witness.signatures,
            state.owners,
            state.threshold
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
    ) public view returns (bool) {
        StateData memory state = bytesToStateData(_exit.state);

        // Check valid transaction sender.
        bool validSender = BasicChecks.checkOwner(tx.origin, state.owners);

        return validSender;
    }

    function finalizeExit(
        Exit memory _exit
    ) public payable {
        StateData memory state = bytesToStateData(_exit.state);

        MultiSig multiSig = new MultiSig(state.owners, state.threshold);
        address(multiSig).transfer(msg.value);
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
        (address[] memory owners, uint256 threshold) = abi.decode(parameters, (address[], uint256));
        return StateData(owners, threshold);
    }
}
