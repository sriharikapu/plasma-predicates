pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;


/**
 * @title Bytes operations
 * @dev Based on https://github.com/GNSPS/solidity-bytes-utils/blob/master/contracts/BytesLib.sol.
 */
library ByteUtils {
    /*
     * Internal functions
     */

    /**
     * @dev Slices off bytes from a byte string.
     * @param _bytes Byte string to slice.
     * @param _start Starting index of the slice.
     * @param _length Length of the slice.
     * @return The slice of the byte string.
     */
    function slice(bytes memory _bytes, uint _start, uint _length) internal pure returns (bytes memory) {
        require(_bytes.length >= (_start + _length), "Slice length cannot be longer than _bytes length");

        bytes memory tempBytes;

        assembly {
            switch iszero(_length)
            case 0 {
                tempBytes := mload(0x40)

                let lengthmod := and(_length, 31)

                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for {
                    let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    mstore(mc, mload(cc))
                }

                mstore(tempBytes, _length)

                mstore(0x40, and(add(mc, 31), not(31)))
            }
            default {
                tempBytes := mload(0x40)

                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }

    function equal(bytes memory _preBytes, bytes memory _postBytes) internal pure returns (bool) {
        bool success = true;

        assembly {
            let length := mload(_preBytes)

        // if lengths don't match the arrays are not equal
            switch eq(length, mload(_postBytes))
            case 1 {
            // cb is a circuit breaker in the for loop since there's
            //  no said feature for inline assembly loops
            // cb = 1 - don't breaker
            // cb = 0 - break
                let cb := 1

                let mc := add(_preBytes, 0x20)
                let end := add(mc, length)

                for {
                    let cc := add(_postBytes, 0x20)
                // the next line is the loop condition:
                // while(uint(mc < end) + cb == 2)
                } eq(add(lt(mc, end), cb), 2) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                // if any of these checks fails then arrays are not equal
                    if iszero(eq(mload(mc), mload(cc))) {
                    // unsuccess:
                        success := 0
                        cb := 0
                    }
                }
            }
            default {
            // unsuccess:
                success := 0
            }
        }

        return success;
    }

    function toBytesBool(bool _value) internal pure returns (bytes memory) {
        bytes memory result;
        assembly {
            result := mload(add(_value, 0x20))
        }
        return result;
    }

    function toBytes(uint8 _value) internal pure returns (bytes memory) {
        bytes memory result;
        assembly {
            result := mload(add(_value, 0x20))
        }
        return result;
    }

    function toUint256(bytes memory _bytes) internal pure returns (uint256) {
        uint256 result;
        assembly {
            result := mload(add(_bytes, 0x20))
        }
        return result;
    }

    function reverse(bytes memory _bytes) internal pure returns (bytes memory) {
        bytes memory reversed = new bytes(_bytes.length);
        for (uint i = 0; i < _bytes.length; i++) {
            reversed[_bytes.length - i - 1] = _bytes[i];
        }
        return reversed;
    }
}
