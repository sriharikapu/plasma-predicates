pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

library BitcoinLib {
    struct Chunk {
        bytes buf;
        uint256 len;
        uint8 opcodenum;
    }

    struct Script {
        uint256 chunkSize;
        uint256 stackSize;
        Chunk[100] chunks;
        bytes[100] stack;
    }

    struct Transaction {
        uint256 nLockTime;
    }

    function pushChunk(Script memory _script, Chunk memory _chunk) internal pure {
        _script.chunks[_script.chunkSize] = _chunk;
        _script.chunkSize++;
    }

    function pushStackItem(Script memory _script, bytes memory _item) internal pure {
        _script.stack[_script.stackSize] = _item;
        _script.stackSize++;
    }

    function pickStack(Script memory _script, uint256 _index) internal pure returns (bytes memory) {
        return _script.stack[_script.stackSize - _index - 1];
    }

    function peekStack(Script memory _script) internal pure returns (bytes memory) {
        return pickStack(_script, 0);
    }

    function popStack(Script memory _script) internal pure returns (bytes memory) {
        bytes memory result = peekStack(_script);
        _script.stackSize--;
        return result;
    }
}
