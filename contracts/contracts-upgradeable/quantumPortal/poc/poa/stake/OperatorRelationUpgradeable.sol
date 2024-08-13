// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOperatorRelation} from "../../../../../quantumPortal/poc/poa/stake/IOperatorRelation.sol";

/**
 * @notice This contract maintains relationship between an delegate and a nodeOperator.
 * delegate is used for stakes, and nodeOperator does the work.
 */
abstract contract OperatorRelationUpgradeable is IOperatorRelation {
    /// @custom:storage-location erc7201:ferrum.storage.operatorrelation.001
    struct OperatorRelationStorageV001 {
        mapping(address => address) nodeOperator;
        mapping(address => IOperatorRelation.Relationship) delegateLookup;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.operatorrelation.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OperatorRelationStorageV001Location = 0x978590d5f23a73ccd0858f9494f6787871cbf0c1462f5a50d6ccad1babbaaf00;

    function _getOperatorRelationStorageV001() internal pure returns (OperatorRelationStorageV001 storage $) {
        assembly {
            $.slot := OperatorRelationStorageV001Location
        }
    }

    event NodeOperatorAssigned(address delegate, address nodeOperator);

    function nodeOperator(address delegate) public view returns (address) {
        return _getOperatorRelationStorageV001().nodeOperator[delegate];
    }

    function delegateLookup(address operator) public view returns (IOperatorRelation.Relationship memory) {
        return _getOperatorRelationStorageV001().delegateLookup[operator];
    }

    /**
     * @inheritdoc IOperatorRelation
     */
    function getDelegateForOperator(
        address operator
    ) external view override returns (IOperatorRelation.Relationship memory) {
        return delegateLookup(operator);
    }

    /**
     * @notice Assigns an operator to the given address from the `msg.sender`. An operator can be used once
     * @param toOp The operator
     */
    function assignOperator(address toOp) external {
        OperatorRelationStorageV001 storage $ = _getOperatorRelationStorageV001();
        address currentOperator = $.nodeOperator[msg.sender];
        if (toOp == address(0)) {
            require(currentOperator != address(0), "D: nothing to delete");
            delete $.nodeOperator[msg.sender];
            $.delegateLookup[currentOperator].deleted = uint8(1);
            emit NodeOperatorAssigned(msg.sender, address(0));
            return;
        }
        require(
            $.delegateLookup[toOp].delegate == address(0),
            "D: to is already in investor"
        );
        require($.nodeOperator[toOp] == address(0), "D: to is an investor");
        require(currentOperator != toOp, "M: nothing will change");
        $.nodeOperator[msg.sender] = toOp;
        if (currentOperator != address(0)) {
            $.delegateLookup[currentOperator].deleted = uint8(1);
        }
        $.delegateLookup[toOp].delegate = msg.sender;
        emit NodeOperatorAssigned(msg.sender, toOp);
    }
}
