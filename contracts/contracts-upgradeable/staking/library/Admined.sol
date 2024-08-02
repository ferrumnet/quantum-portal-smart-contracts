// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {StakingBasics} from "../../../staking/library/StakingBasics.sol";


abstract contract Admined is OwnableUpgradeable {
	/// @custom:storage-location erc7201:ferrum.storage.admined.001
	struct AdminedStorageV001 {
		mapping(address => mapping(address => StakingBasics.AdminRole)) admins;
	}

	// keccak256(abi.encode(uint256(keccak256("ferrum.storage.admined.001")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant AdminedStorageV001Location = 0x883f681cb97e6edc0a14ed7ba62c50cb62809c2d5f46fe1d2f0c15567de35e00;
	
	function admins(address id, address admin) public view returns (StakingBasics.AdminRole) {
		return _getAdminedStorageV001().admins[id][admin];
	}

	function setAdmin(address id, address admin, StakingBasics.AdminRole role) onlyOwner external {
		AdminedStorageV001 storage $ = _getAdminedStorageV001();
		$.admins[id][admin] = role;
	}

	function _getAdminedStorageV001() internal pure returns (AdminedStorageV001 storage $) {
		assembly {
			$.slot := AdminedStorageV001Location
		}
	}
}
