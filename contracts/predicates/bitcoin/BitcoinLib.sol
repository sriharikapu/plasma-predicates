pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./StackLib.sol";

library BitcoinLib {
    struct Chunk {
        bytes buf;
        uint256 len;
        uint8 opcodenum;
    }

    struct Script {
        uint256 chunkSize;
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
}
