// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgradeable, Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {WithAdmin} from "foundry-contracts/contracts/contracts-upgradeable/common/WithAdmin.sol";
import {IDelegator} from "../../../../quantumPortal/poc/poa/IDelegator.sol";


/**
 * @notice A delegator allows delegation.
 */
contract Delegator is Initializable, UUPSUpgradeable, WithAdmin {
    /// @custom:storage-location erc7201:ferrum.storage.delegator.001
    struct DelegatorStorageV001 {
        mapping(address => address) delegation;
        mapping(address => IDelegator.ReverseDelegation) reverseDelegation;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.delegator.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant DelegatorStorageV001Location = 0xf5bb349c9eb4a7e2375754f6b8067bc31c1aa3cc007d281e4d733c138db7fb00;

    function initialize(address initialOwnerAdmin) public initializer {
        __WithAdmin_init(initialOwnerAdmin, initialOwnerAdmin);
    }

    function _getDelegatorStorageV001() internal pure returns (DelegatorStorageV001 storage $) {
        assembly {
            $.slot := DelegatorStorageV001Location
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    event Delegated(address delator, address delegatee);

    /**
     * @notice Returns the reverse delegation for a delegatee
     * @param key The key
     */
    function getReverseDelegation(
        address key
    ) external view returns (IDelegator.ReverseDelegation memory) {
        return _getDelegatorStorageV001().reverseDelegation[key];
    }

    /**
     * @notice Delegates to the given address from the `msg.sender`. A delegatee can be used once
     * @param to The delegatee
     */
    function delegate(address to) external {
        DelegatorStorageV001 storage $ = _getDelegatorStorageV001();
        address currentDelegation = $.delegation[msg.sender];
        if (to == address(0)) {
            require(currentDelegation != address(0), "D: nothing to delete");
            delete $.delegation[msg.sender];
            $.reverseDelegation[currentDelegation].deleted = uint8(1);
            emit Delegated(msg.sender, address(0));
            return;
        }
        require(
            $.reverseDelegation[to].delegatee == address(0),
            "D: to is already delegated to other"
        );
        require($.delegation[to] == address(0), "D: to has a delegation already");
        require(currentDelegation != to, "M: nothing will change");
        $.delegation[msg.sender] = to;
        $.reverseDelegation[currentDelegation].deleted = uint8(1);
        $.reverseDelegation[to].delegatee = msg.sender;
        emit Delegated(msg.sender, to);
    }
}
