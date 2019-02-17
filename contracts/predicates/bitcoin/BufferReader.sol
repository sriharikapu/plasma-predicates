pragma solidity ^0.5.0;

import "../../libraries/ByteUtils.sol";

library BufferReader {
    using ByteUtils for bytes;

    struct Reader {
        uint256 ptr;
        bytes value;
    }

    function readUInt8True(Reader memory _reader) internal pure returns (uint8) {
        return uint8(readUInt8(_reader));
    }

    function readUInt8(Reader memory _reader) internal pure returns (uint256) {
        return read(_reader, 1).toUint256();
    }

    function readUInt16LE(Reader memory _reader) internal pure returns (uint256) {
        return read(_reader, 2).reverse().toUint256();
    }

    function readUInt32LE(Reader memory _reader) internal pure returns (uint256) {
        return read(_reader, 4).reverse().toUint256();
    }

    function read(Reader memory _reader, uint _length) internal pure returns (bytes memory) {
        bytes memory val = _reader.value.slice(_reader.ptr, _length);
        _reader.ptr += _length;
        return val;
    }

    function finished(Reader memory _reader) internal pure returns (bool) {
        return _reader.ptr < _reader.value.length;
    }
}
