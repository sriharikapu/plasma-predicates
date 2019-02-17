pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./StackLib.sol";
import "../../libraries/ByteUtils.sol";

library BitcoinLib {
    using ByteUtils for bytes;

    struct Chunk {
        bytes buf;
        uint256 len;
        uint8 opcodenum;
    }

    struct Script {
        uint256 chunkSize;
        uint256 separator;
        Chunk[100] chunks;
        StackLib.Stack stack;
        StackLib.Stack execStack;
    }

    struct Transaction {
        uint256 nLockTime;
    }

    function pushChunk(Script memory _script, Chunk memory _chunk) internal pure {
        _script.chunks[_script.chunkSize] = _chunk;
        _script.chunkSize++;
    }
    
    function subScript(Script memory _script, uint256 _start) internal pure returns (Script memory) {
        Chunk[100] memory chunks;
        for (uint i = 0; i < _script.chunks.length; i++) {
            chunks[i] = _script.chunks[i + _start];
        }
        Script memory newScript;
        newScript.chunks = chunks;
        return newScript;
    }

    function deleteChunk(Script memory _script, bytes memory _value) internal pure {
        uint256 totalChunks;
        Chunk[100] memory chunks;
        for (uint i = 0; i < _script.chunks.length; i++) {
            if (!_script.chunks[i].buf.equal(_value)) {
                chunks[totalChunks] = _script.chunks[i];
                totalChunks++;
            }
        }
        _script.chunks = chunks;
    }
}
