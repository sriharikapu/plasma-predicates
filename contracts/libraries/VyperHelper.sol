pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

contract IPredicate {
    /*
     * Structs
     */

    struct StateObject {
        bytes parameters;
        address predicate;
    }

    struct Exit {
        bytes state;
        uint256 rangeStart; // typed
        uint256 rangeEnd;
        uint256 exitHeight; // plasma block height
        uint256 exitTime; // eth block number exit was started
    }


    /*
     * Public methods
     */

    function encodeExit(
        bytes memory _state,
        uint256 _typedStart,
        uint256 _typedEnd,
        uint256 _exitPlasmaBlock,
        uint256 _exitEthBlock
    ) public view returns (bytes memory){
        return abi.encode(_state, _typedStart, _typedEnd, _exitPlasmaBlock, _exitEthBlock);
    }

    function decodePredicateFromState(
        bytes memory _stateObject
    ) public view returns (address){
        ( ,address predAddr) = abi.decode(_stateObject, (bytes, address));
        return predAddr;
    }

}
