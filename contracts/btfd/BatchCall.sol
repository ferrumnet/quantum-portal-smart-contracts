pragma solidity ^0.8.24;

error CallFailed(address target, bytes call, bytes err);

contract BatchCall {
    function batchCall(address target, bytes[] calldata calls) external {
        for(uint i=0; i<calls.length; i++) {
            (bool result, bytes memory err) = target.call(calls[i]);
            if (!result) revert CallFailed(target, calls[i], err);
        }
    }
}