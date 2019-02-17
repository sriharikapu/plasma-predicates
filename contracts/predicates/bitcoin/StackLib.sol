pragma solidity ^0.5.0;

library StackLib {
    struct Stack {
        uint256 size;
        bytes[100] items;
    }

    function push(Stack memory _stack, bytes memory _item) internal pure {
        _stack.items[_stack.size] = _item;
        _stack.size++;
    }

    function pick(Stack memory _stack, uint256 _index) internal pure returns (bytes memory) {
        return _stack.items[_stack.size - _index - 1];
    }

    function peek(Stack memory _stack) internal pure returns (bytes memory) {
        return pick(_stack, 0);
    }

    function pop(Stack memory _stack) internal pure returns (bytes memory) {
        bytes memory result = peek(_stack);
        _stack.size--;
        return result;
    }
}
