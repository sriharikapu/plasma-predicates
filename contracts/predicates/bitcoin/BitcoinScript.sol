pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./BitcoinLib.sol";
import "./StackLib.sol";
import "./BufferReader.sol";
import "../../libraries/ByteUtils.sol";

contract BitcoinScript {
    using BufferReader for BufferReader.Reader;
    using BitcoinLib for BitcoinLib.Script;
    using StackLib for StackLib.Stack;
    using ByteUtils for uint8;
    using ByteUtils for bytes;
    using ByteUtils for bool;

    /*
     * Opcodes
     */

    /* push value */
    uint8 constant OP_0 = 0x00;
    uint8 constant OP_FALSE = OP_0;
    uint8 constant OP_PUSHDATA1 = 0x4c;
    uint8 constant OP_PUSHDATA2 = 0x4d;
    uint8 constant OP_PUSHDATA4 = 0x4e;
    uint8 constant OP_1NEGATE = 0x4f;
    uint8 constant OP_RESERVED = 0x50;
    uint8 constant OP_1 = 0x51;
    uint8 constant OP_TRUE = OP_1;
    uint8 constant OP_2 = 0x52;
    uint8 constant OP_3 = 0x53;
    uint8 constant OP_4 = 0x54;
    uint8 constant OP_5 = 0x55;
    uint8 constant OP_6 = 0x56;
    uint8 constant OP_7 = 0x57;
    uint8 constant OP_8 = 0x58;
    uint8 constant OP_9 = 0x59;
    uint8 constant OP_10 = 0x5a;
    uint8 constant OP_11 = 0x5b;
    uint8 constant OP_12 = 0x5c;
    uint8 constant OP_13 = 0x5d;
    uint8 constant OP_14 = 0x5e;
    uint8 constant OP_15 = 0x5f;
    uint8 constant OP_16 = 0x60;

    /* control */
    uint8 constant OP_NOP = 0x61;
    uint8 constant OP_VER = 0x62;
    uint8 constant OP_IF = 0x63;
    uint8 constant OP_NOTIF = 0x64;
    uint8 constant OP_VERIF = 0x65;
    uint8 constant OP_VERNOTIF = 0x66;
    uint8 constant OP_ELSE = 0x67;
    uint8 constant OP_ENDIF = 0x68;
    uint8 constant OP_VERIFY = 0x69;
    uint8 constant OP_RETURN = 0x6a;

    /* stack ops */
    uint8 constant OP_TOALTSTACK = 0x6b;
    uint8 constant OP_FROMALTSTACK = 0x6c;
    uint8 constant OP_2DROP = 0x6d;
    uint8 constant OP_2DUP = 0x6e;
    uint8 constant OP_3DUP = 0x6f;
    uint8 constant OP_2OVER = 0x70;
    uint8 constant OP_2ROT = 0x71;
    uint8 constant OP_2SWAP = 0x72;
    uint8 constant OP_IFDUP = 0x73;
    uint8 constant OP_DEPTH = 0x74;
    uint8 constant OP_DROP = 0x75;
    uint8 constant OP_DUP = 0x76;
    uint8 constant OP_NIP = 0x77;
    uint8 constant OP_OVER = 0x78;
    uint8 constant OP_PICK = 0x79;
    uint8 constant OP_ROLL = 0x7a;
    uint8 constant OP_ROT = 0x7b;
    uint8 constant OP_SWAP = 0x7c;
    uint8 constant OP_TUCK = 0x7d;

    /* splice ops */
    uint8 constant OP_CAT = 0x7e;
    uint8 constant OP_SUBSTR = 0x7f;
    uint8 constant OP_LEFT = 0x80;
    uint8 constant OP_RIGHT = 0x81;
    uint8 constant OP_SIZE = 0x82;

    /* bit logic */
    uint8 constant OP_INVERT = 0x83;
    uint8 constant OP_AND = 0x84;
    uint8 constant OP_OR = 0x85;
    uint8 constant OP_XOR = 0x86;
    uint8 constant OP_EQUAL = 0x87;
    uint8 constant OP_EQUALVERIFY = 0x88;
    uint8 constant OP_RESERVED1 = 0x89;
    uint8 constant OP_RESERVED2 = 0x8a;

    /* numeric */
    uint8 constant OP_1ADD = 0x8b;
    uint8 constant OP_1SUB = 0x8c;
    uint8 constant OP_2MUL = 0x8d;
    uint8 constant OP_2DIV = 0x8e;
    uint8 constant OP_NEGATE = 0x8f;
    uint8 constant OP_ABS = 0x90;
    uint8 constant OP_NOT = 0x91;
    uint8 constant OP_0NOTEQUAL = 0x92;

    uint8 constant OP_ADD = 0x93;
    uint8 constant OP_SUB = 0x94;
    uint8 constant OP_MUL = 0x95;
    uint8 constant OP_DIV = 0x96;
    uint8 constant OP_MOD = 0x97;
    uint8 constant OP_LSHIFT = 0x98;
    uint8 constant OP_RSHIFT = 0x99;

    uint8 constant OP_BOOLAND = 0x9a;
    uint8 constant OP_BOOLOR = 0x9b;
    uint8 constant OP_NUMEQUAL = 0x9c;
    uint8 constant OP_NUMEQUALVERIFY = 0x9d;
    uint8 constant OP_NUMNOTEQUAL = 0x9e;
    uint8 constant OP_LESSTHAN = 0x9f;
    uint8 constant OP_GREATERTHAN = 0xa0;
    uint8 constant OP_LESSTHANOREQUAL = 0xa1;
    uint8 constant OP_GREATERTHANOREQUAL = 0xa2;
    uint8 constant OP_MIN = 0xa3;
    uint8 constant OP_MAX = 0xa4;

    uint8 constant OP_WITHIN = 0xa5;

    /* crypto */
    uint8 constant OP_RIPEMD160 = 0xa6;
    uint8 constant OP_SHA1 = 0xa7;
    uint8 constant OP_SHA256 = 0xa8;
    uint8 constant OP_HASH160 = 0xa9;
    uint8 constant OP_HASH256 = 0xaa;
    uint8 constant OP_CODESEPARATOR = 0xab;
    uint8 constant OP_CHECKSIG = 0xac;
    uint8 constant OP_CHECKSIGVERIFY = 0xad;
    uint8 constant OP_CHECKMULTISIG = 0xae;
    uint8 constant OP_CHECKMULTISIGVERIFY = 0xaf;

    /* expansion */
    uint8 constant OP_NOP1 = 0xb0;
    uint8 constant OP_NOP2 = 0xb1;
    uint8 constant OP_CHECKLOCKTIMEVERIFY = OP_NOP2;
    uint8 constant OP_NOP3 = 0xb2;
    uint8 constant OP_NOP4 = 0xb3;
    uint8 constant OP_NOP5 = 0xb4;
    uint8 constant OP_NOP6 = 0xb5;
    uint8 constant OP_NOP7 = 0xb6;
    uint8 constant OP_NOP8 = 0xb7;
    uint8 constant OP_NOP9 = 0xb8;
    uint8 constant OP_NOP10 = 0xb9;

    /* template matching params */
    uint8 constant OP_SMALLINTEGER = 0xfa;
    uint8 constant OP_PUBKEYS = 0xfb;
    uint8 constant OP_PUBKEYHASH = 0xfd;
    uint8 constant OP_PUBKEY = 0xfe;

    uint8 constant OP_INVALIDOPCODE = 0xff;

    /*
    function verify(bytes memory _scriptSig, bytes memory _scriptPubkey) public pure returns (bool) {

    }
    */

    function evaluate(bytes memory _script) public pure returns (bool) {
        BitcoinLib.Script memory script = bytesToScript(_script);

    }

    function step(
        BitcoinLib.Script memory _script,
        BitcoinLib.Transaction memory _transaction,
        uint256 _step
    ) internal pure returns (bool, string memory) {
        BitcoinLib.Chunk memory chunk = _script.chunks[_step];
        uint8 opcodenum = chunk.opcodenum;

        bytes memory buf;
        if (opcodenum > 0 && opcodenum <= OP_PUSHDATA4) {
            _script.stack.push(chunk.buf);
        } else if (OP_IF <= opcodenum && opcodenum <= OP_ENDIF) {
            if (
                opcodenum == OP_1NEGATE ||
                opcodenum == OP_1 ||
                opcodenum == OP_2 ||
                opcodenum == OP_3 ||
                opcodenum == OP_4 ||
                opcodenum == OP_5 ||
                opcodenum == OP_6 ||
                opcodenum == OP_7 ||
                opcodenum == OP_8 ||
                opcodenum == OP_9 ||
                opcodenum == OP_10 ||
                opcodenum == OP_11 ||
                opcodenum == OP_12 ||
                opcodenum == OP_13 ||
                opcodenum == OP_14 ||
                opcodenum == OP_15 ||
                opcodenum == OP_16
            ) {
                buf = (opcodenum - (OP_1 - 1)).toBytes();
                _script.stack.push(buf);
            } else if (
                opcodenum == OP_NOP2 ||
                opcodenum == OP_CHECKLOCKTIMEVERIFY
            ) {
                if (_script.stack.size < 1) {
                    return (false, "SCRIPT_ERR_INVALID_STACK_OPERATION");
                }
                uint256 nLockTime = _script.stack.peek().toUint256();
                if (nLockTime > _transaction.nLockTime) {
                    return (false, "SCRIPT_ERR_UNSATISFIED_LOCKTIME");
                }
            } else if (
                opcodenum == OP_EQUAL ||
                opcodenum == OP_EQUALVERIFY
            ) {
                if (_script.stack.size < 2) {
                    return (false, "SCRIPT_ERR_INVALID_STACK_OPERATION");
                }
                bytes memory buf1 = _script.stack.pick(1);
                bytes memory buf2 = _script.stack.pick(0);
                bool isEqual = buf1.equal(buf2);
                _script.stack.pop();
                _script.stack.pop();
                _script.stack.push(abi.encodePacked(isEqual));
                if (opcodenum == OP_EQUALVERIFY) {
                    if (isEqual) {
                        _script.stack.pop();
                    } else {
                        return (false, "SCRIPT_ERR_EQUALVERIFY");
                    }
                }
            } else if (
                opcodenum == OP_IF ||
                opcodenum == OP_NOTIF
            ) {
                if (_script.stack.size < 1) {
                    return (false, "SCRIPT_ERR_UNBALANCED_CONDITIONAL");
                }
                buf = _script.stack.peek();
                bool isTrue = (buf.toUint256() != 0);
                if (opcodenum == OP_NOTIF) {
                    isTrue = !isTrue;
                }
                _script.stack.pop();
                _script.stack.push(isTrue.toBytesBool());
            } else if (
                opcodenum == OP_ELSE
            ) {
                
            } else if (
                opcodenum == OP_DROP
            ) {
                if (_script.stack.size < 1) {
                    return (false, "SCRIPT_ERR_INVALID_STACK_OPERATION");
                }
                _script.stack.pop();
            } else if (
                opcodenum == OP_RIPEMD160 ||
                opcodenum == OP_SHA256 ||
                opcodenum == OP_HASH160 ||
                opcodenum == OP_HASH256
            ) {
                if (_script.stack.size < 1) {
                    return (false, "SCRIPT_ERR_INVALID_STACK_OPERATION");
                }
                buf = _script.stack.peek();
                bytes32 bufHash;
                if (opcodenum == OP_RIPEMD160) {
                    bufHash = ripemd160(buf);
                } else if (opcodenum == OP_SHA256) {
                    bufHash = keccak256(buf);
                } else if (opcodenum == OP_HASH160) {
                    bufHash = keccak256(abi.encodePacked(ripemd160(buf)));
                } else if (opcodenum == OP_HASH256) {
                    bufHash = keccak256(abi.encodePacked(keccak256(buf)));
                }
                _script.stack.pop();
                _script.stack.push(abi.encodePacked(bufHash));
            }
        }

        return (true, "");
    }

    function bytesToScript(bytes memory _script) internal pure returns (BitcoinLib.Script memory) {
        BitcoinLib.Script memory script;
        BufferReader.Reader memory br = BufferReader.Reader(0, _script);
        while (!br.finished()) {
            // Read the next opcode.
            uint8 opcodenum = br.readUInt8True();

            bytes memory buf;
            uint256 len;
            if (opcodenum > 0 && opcodenum < OP_PUSHDATA1) {
                len = opcodenum;
                buf = br.read(len);
            } else if (opcodenum == OP_PUSHDATA1) {
                len = br.readUInt8();
                buf = br.read(len);
            } else if (opcodenum == OP_PUSHDATA2) {
                len = br.readUInt16LE();
                buf = br.read(len);
            } else if (opcodenum == OP_PUSHDATA4) {
                len = br.readUInt32LE();
                buf = br.read(len);
            }

            script.pushChunk(BitcoinLib.Chunk(
                buf,
                len,
                opcodenum
            ));
        }

        return script;
    }
}

// TODO: Handle disabled opcodes.
