// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @notice Library for handling safe token transactions including fee per transaction tokens.
 */
abstract contract TokenReceivableUpgradeable is Initializable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;
	/// @custom:storage-location erc7201:ferrum.storage.tokenreceivable.001
	struct TokenReceivableStorageV001 {
		mapping(address => uint256) inventory;
	}

	// keccak256(abi.encode(uint256(keccak256("ferrum.storage.tokenreceivable.001")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant TokenReceivableStorageV001Location = 0x9c42703b72201b793e2c464b8e3efb1d652cc64357b00d5687b971a87e802800;

	function __TokenReceivable_init() internal onlyInitializing {
		__ReentrancyGuard_init();
	}

	function __TokenReceivable_init_unchained() internal onlyInitializing {}

	function _getTokenReceivableStorageV001() internal pure returns (TokenReceivableStorageV001 storage $) {
		assembly {
			$.slot := TokenReceivableStorageV001Location
		}
	}

    /**
     @notice Sync the inventory of a token based on amount changed
    @param token The token address
    @return amount The changed amount
    */
    function sync(address token) internal returns (uint256 amount) {
		TokenReceivableStorageV001 storage $ = _getTokenReceivableStorageV001();
        uint256 inv = $.inventory[token];
        uint256 balance = IERC20(token).balanceOf(address(this));
        amount = balance - inv;
        $.inventory[token] = balance;
    }

    /**
     @notice Safely sends a token out and updates the inventory
    @param token The token address
    @param payee The payee
    @param amount The amount
    */
    function sendToken(
        address token,
        address payee,
        uint256 amount
    ) internal nonReentrant {
		TokenReceivableStorageV001 storage $ = _getTokenReceivableStorageV001();
        $.inventory[token] = $.inventory[token] - amount;
        IERC20(token).safeTransfer(payee, amount);
    }
}
