pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import './IPredicate.sol';
import './BasicChecks.sol';

contract SimpleMultiSig is IPredicate {
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
    ) public returns (bool) {
        Witness memory witness = bytesToWitness(_witness);
        StateData memory state = bytesToStateData(_exit.state);

        // Check transaction signature.
        uint256 signatures = 0;
        for (uint256 i = 0; i < state.owners.length; i++) {
            bool validSignature = BasicChecks.checkSignature(
                witness.rangeStart,
                witness.rangeEnd,
                _exit.exitHeight,
                witness.signatures[i],
                state.owners[i]
            );
            if (validSignature) {
                signatures++;
            }
        }
        bool validSignatures = (signatures >= state.threshold);

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
        bool validSender = false;
        for (uint256 i = 0; i < state.owners.length; i++) {
            if (tx.origin == state.owners[i]) {
                validSender = true;
            }
        }

        return validSender;
    }

    function finalizeExit(
        Exit memory _exit,
        bytes memory _witness
    ) public payable {
        StateData memory state = bytesToStateData(_exit.state);
        
        // TODO: Convert into a multisig on the main chain.
    }


    /*
     * Internal functions
     */

    function bytesToWitness(
        bytes memory _witness
    ) internal pure returns (Witness memory) {
        (uint256 rangeStart, uint256 rangeEnd, bytes[] memory signatures) = abi.decode(_witness, (uint256, uint256, bytes[]));
        return Witness(
            rangeStart,
            rangeEnd,
            signatures
        );
    }

    function bytesToStateData(
        bytes memory _state
    ) internal pure returns (StateData memory) {
        (bytes memory parameters, ) = abi.decode(_state, (bytes, address));
        (address[] memory owners, uint256 threshold) = abi.decode(parameters, (address[], uint256));
        return StateData(
            owners,
            threshold
        );
    }
}