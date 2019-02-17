pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./Lightning.sol";
import "../../libraries/BasicChecks.sol";
import "../IPredicate.sol";

contract LightningPredicate is IPredicate {
    /*
     * Structs
     */

    struct StateData {
        bytes[] inputScripts;
    }

    struct Witness {
        uint256 rangeStart;
        uint256 rangeEnd;
        bytes witnesses;
        bytes outputScripts;
    }

    /*
     * Public Functions
     */
    
    function canCancel(
        Exit memory _exit,
        bytes memory _witness
    ) public view returns (bool) {
        Witness memory witness = bytesToWitness(_witness);
        StateData memory state = bytesToStateData(_exit.state);
        
        // Check valid lightning spend.
        bool validSpend = Lightning.checkValidSpend(witness.witnesses, state.inputScripts, witness.outputScripts);

        // Check transaction bounds.
        bool validBounds = BasicChecks.checkBounds(
            _exit.rangeStart,
            _exit.rangeEnd,
            witness.rangeStart,
            witness.rangeEnd
        );

        return validSpend && validBounds;
    }

    function canStartExit(
        Exit memory _exit
    ) public view returns (bool) {
        // TODO: Figure out how to check this.
        return true;
    }

    function finalizeExit(
        Exit memory _exit
    ) public payable {
        // TODO: Figure out how to handle this.
    }


    /*
     * Internal Functions
     */

    function bytesToWitness(
        bytes memory _witness
    ) internal pure returns (Witness memory) {
        (uint256 rangeStart, uint256 rangeEnd, bytes memory witnesses, bytes memory outputScripts) = abi.decode(_witness, (uint256, uint256, bytes, bytes));
        return Witness(rangeStart, rangeEnd, witnesses, outputScripts);
    }

    function bytesToStateData(
        bytes memory _state
    ) internal pure returns (StateData memory) {
        (bytes memory parameters, ) = abi.decode(_state, (bytes, address));
        bytes[] memory inputScripts = abi.decode(parameters, (bytes[]));
        return StateData(inputScripts);
    }
}
