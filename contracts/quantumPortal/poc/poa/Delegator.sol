// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @notice A delegator allows delegation.
 */
contract Delegator {
    event Delegated(address delator, address delegatee);
    mapping(address => address) delegation;
    mapping(address => address) reverseDelegation;

    function delegate(address to
    ) external {
        address currentDelegation = delegation[msg.sender];
        if (to == address(0)) {
            require(currentDelegation != address(0), "D: nothing to delete");
            delete delegation[msg.sender];
            delete reverseDelegation[currentDelegation];
            emit Delegated(msg.sender, address(0));
            return;
        }
        require(reverseDelegation[to] == address(0), "D: to is already delegated to other");
        require(delegation[to] == address(0), "D: to has a delegation already");
        require(currentDelegation != to, "M: nothing will change");
        delegation[msg.sender] = to;
        delete reverseDelegation[currentDelegation];
        reverseDelegation[to] = msg.sender;
        emit Delegated(msg.sender, to);
    }
}