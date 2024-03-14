// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IOperatorRelation.sol";

/**
 * @notice This contract maintains relationship between an investor and a worker.
 * Investor puts the money, and worker does the work.
 */
abstract contract OperatorRelation is IOperatorRelation {
    mapping(address => address) public nodeOperator;
    mapping(address => IOperatorRelation.Relationship) public delegateLookup;
    event NodeOperatorAssigned(address investor, address nodeOperator);

    /**
     * @inheritdoc IOperatorRelation
     */
    function getDelegateForOperator(
        address operator
    ) external view override returns (IOperatorRelation.Relationship memory) {
        return delegateLookup[operator];
    }

    /**
     * @notice Assigns an operator to the given address from the `msg.sender`. An operator can be used once
     * @param to The operator
     */
    function assignOperator(address to) external {
        address currentOperator = nodeOperator[msg.sender];
        if (to == address(0)) {
            require(currentOperator != address(0), "D: nothing to delete");
            delete nodeOperator[msg.sender];
            delegateLookup[currentOperator].deleted = uint8(1);
            emit NodeOperatorAssigned(msg.sender, address(0));
            return;
        }
        require(
            delegateLookup[to].delegate == address(0),
            "D: to is already in investor"
        );
        require(nodeOperator[to] == address(0), "D: to is an investor");
        require(currentOperator != to, "M: nothing will change");
        nodeOperator[msg.sender] = to;
        if (currentOperator != address(0)) {
            delegateLookup[currentOperator].deleted = uint8(1);
        }
        delegateLookup[to].delegate = msg.sender;
        emit NodeOperatorAssigned(msg.sender, to);
    }
}
