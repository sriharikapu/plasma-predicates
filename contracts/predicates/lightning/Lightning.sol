pragma solidity ^0.5.0;

import "../../libraries/ByteUtils.sol";
import "../../libraries/ECRecovery.sol";

library Lightning {
    using ByteUtils for bytes;

    bytes1 constant PAYMENT_SIGIL = 0x01;
    bytes1 constant MULTISIG_SIGIL = 0x02;
    bytes1 constant LOCAL_COMMIT_SIGIL = 0x03;
    bytes1 constant HTLC_OFFER_SIGIL = 0x04;
    
    bytes constant ZERO_SIG = new bytes(65);
    bytes constant ZERO_BYTES = new bytes(0);
    address constant ZERO_ADDRESS = address(0);
    bytes32 constant ZERO_BYTES32 = bytes32(0);
    
    struct Output {
        uint value;
        uint blockNum;
        bytes script;
        bytes32 id;
        bool exists;
    }

    function checkValidSpend(bytes memory witnesses, bytes[] memory inputScripts, bytes memory outputScripts) internal view returns (bool) {
        uint totalInputValue = processInputs(witnesses, inputScripts, outputScripts);
    
        uint cursor = 0;
        uint totalOutputValue = 0;
        uint index = 0;

        while (cursor < outputScripts.length) {
            uint value = outputScripts.toUint(cursor);
            cursor += 32;
            bytes1 sigil = outputScripts[cursor];
            uint16 scriptLen = scriptLength(sigil);
            require(scriptLen > 0, "Script length must be greater than zero.");
            require(outputScripts.length - cursor >= scriptLen, "Output script is too short.");
            cursor += scriptLen;
            totalOutputValue += value;
            index++;
        }

        require(totalInputValue == totalOutputValue, "Mismatched input and output values.");
        return true;
    }

    function processInputs(bytes memory witnesses, bytes[] memory inputScripts, bytes memory outputScripts) internal view returns (uint) {
        uint cursor = 0;
        uint totalInputValue = 0;
        uint inputNumber = 0;

        // outputid (32), witness
        while (cursor < witnesses.length) {
            uint16 witnessLen = witnesses.toUint16(cursor);
            cursor += 16;

            bytes memory witness = witnesses.slice(cursor, witnessLen);
            cursor += witnessLen;

            Output memory input = parseInputScript(inputScripts[inputNumber]);
            require(isSpendable(input, witness, outputScripts), "Invalid spend.");
            totalInputValue += input.value;
            inputNumber++;
        }
    
        return totalInputValue;
    }

    function parseInputScript(bytes memory inputScript) internal view returns (Output memory) {
        uint cursor = 0;
        uint value = inputScript.toUint(cursor);
        cursor += 32;

        bytes1 sigil = inputScript[cursor];
        uint16 scriptLen = scriptLength(sigil);
        bytes memory script = inputScript.slice(cursor, scriptLen);
        cursor += scriptLen;
        bytes32 inputsHash = inputScript.slice32(cursor);
        cursor += 32;
        uint inputIndex = inputScript.toUint(cursor);

        Output memory out = Output(
            value,
            block.number,
            script,
            keccak256(abi.encodePacked(inputsHash, script, value, inputIndex)),
            true
        );

        return out;
    }

    function verify(bytes32 data, address expected, bytes memory sig) internal pure returns (bool) {
        return ECRecovery.recover(data, sig) == expected;
    }

    function isSpendable(Output memory out, bytes memory witness, bytes memory outputScripts) internal view returns (bool) {
        bytes1 sigil = out.script[0];
        
        if (sigil == PAYMENT_SIGIL) {
            return isPaymentSpendable(out, witness, outputScripts);
        }

        if (sigil == MULTISIG_SIGIL) {
            return isMultisigSpendable(out, witness, outputScripts);
        }

        if (sigil == LOCAL_COMMIT_SIGIL) {
            return isLocalCommitSpendable(out, witness, outputScripts);
        }

        if (sigil == HTLC_OFFER_SIGIL) {
            return isHTLCOfferSpendable(out, witness);
        }

        return false;
    }

    function isPaymentSpendable(Output memory out, bytes memory witness, bytes memory outputScripts) internal pure returns (bool) {
        bytes32 hash = keccak256(abi.encodePacked(out.id, witness.slice(0, 1), outputScripts));
        bytes memory sig = witness.slice(1, 65);
        address redeemer = out.script.toAddress(1);
        return verify(hash, redeemer, sig);
    }

    function isMultisigSpendable(Output memory out, bytes memory witness, bytes memory outputScripts) internal pure returns (bool) {
        uint cursor = 0;
        bytes32 hash = keccak256(abi.encodePacked(out.id, witness.slice(0, 1), outputScripts));
        cursor += 1;
        bytes memory sigA = witness.slice(cursor, 65);
        cursor += 65;
        bytes memory sigB = witness.slice(cursor, 65);

        address partyA = out.script.toAddress(1);
        address partyB = out.script.toAddress(21);
        return verify(hash, partyA, sigA) && verify(hash, partyB, sigB);
    }

    function isLocalCommitSpendable(Output memory out, bytes memory witness, bytes memory outputScripts) internal view returns (bool) {
        bytes32 hash = keccak256(abi.encodePacked(out.id, witness.slice(0, 1), outputScripts));
        bytes1 txType = witness[0];
        bytes memory sig = witness.slice(1, 65);
        
        if (txType == 0x01) {
            address revocation = out.script.toAddress(53);
            return verify(hash, revocation, sig);
        }
        
        uint delay = out.script.toUint(1);
        if (out.blockNum + delay >= block.number) {
            return false;
        }
        
        address delayed = out.script.toAddress(33);
        return verify(hash, delayed, sig);
    }
    
    function isHTLCOfferSpendable(Output memory out, bytes memory witness) internal view returns (bool) {
        bytes1 txType = witness[0];
        
        if (txType == 0x00) {
            address redemption = out.script.toAddress(33);
            bytes32 preimage = witness.slice32(1);
            bytes32 expectedHash = out.script.slice32(73);
            return sha256(abi.encodePacked(preimage)) == expectedHash && msg.sender == redemption;
        }

        // 0x01 for timeout
        if (txType != 0x01) {
            return true;
        }

        uint delay = out.script.toUint(1);
        if (out.blockNum + delay >= block.number) {
            return false;
        }

        address timeout = out.script.toAddress(53);
        bytes32 hash = keccak256(abi.encodePacked(out.id, witness.slice(0, 1)));
        bytes memory sig = witness.slice(1, 65);
        return verify(hash, timeout, sig);
    }

    function scriptLength(bytes1 sigil) internal pure returns (uint16) {
        if (sigil == PAYMENT_SIGIL) {
            return 21;
        }
        
        if (sigil == MULTISIG_SIGIL) {
            return 41;
        }
        
        if (sigil == LOCAL_COMMIT_SIGIL) {
            return 73;
        }
        
        if (sigil == HTLC_OFFER_SIGIL) {
            return 105;
        }
        
        return 0;
    }
}
