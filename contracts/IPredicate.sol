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
        uint256 rangeStart;
        uint256 rangeEnd;
        uint256 exitHeight;
        uint256 exitTime;
    }


    /*
     * Public methods
     */

    function canCancel(
        Exit memory _exit,
        bytes memory _witness
    ) public returns (bool);

    function canStartExit(
        Exit memory _exit,
        bytes memory _witness
    ) public returns (bool);

    function finalizeExit(
        Exit memory _exit,
        bytes memory _witness
    ) public payable;
}
