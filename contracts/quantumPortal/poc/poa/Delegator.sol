// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IDelegator.sol";

/**
 * @notice A delegator allows delegation.
 */
contract Delegator is IDelegator {
    event Delegated(address delator, address delegatee);
    mapping(address => address) public delegation;
    mapping(address => IDelegator.ReverseDelegation) public reverseDelegation;

    /**
     * @notice Returns the reverse delegation for a delegatee
     * @param key The key
     */
    function getReverseDelegation(
        address key
    ) external view override returns (IDelegator.ReverseDelegation memory) {
        return reverseDelegation[key];
    }

    /**
     * @notice Delegates to the given address from the `msg.sender`. A delegatee can be used once
     * @param to The delegatee
     */
    function delegate(address to) external {
        address currentDelegation = delegation[msg.sender];
        if (to == address(0)) {
            require(currentDelegation != address(0), "D: nothing to delete");
            delete delegation[msg.sender];
            reverseDelegation[currentDelegation].deleted = uint8(1);
            emit Delegated(msg.sender, address(0));
            return;
        }
        require(
            reverseDelegation[to].delegatee == address(0),
            "D: to is already delegated to other"
        );
        require(delegation[to] == address(0), "D: to has a delegation already");
        require(currentDelegation != to, "M: nothing will change");
        delegation[msg.sender] = to;
        reverseDelegation[currentDelegation].deleted = uint8(1);
        reverseDelegation[to].delegatee = msg.sender;
        emit Delegated(msg.sender, to);
    }
}
