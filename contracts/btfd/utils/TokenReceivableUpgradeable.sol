// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ITokenReceivable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @notice Library for handling safe token transactions including fee per transaction tokens.
 */
abstract contract TokenReceivableUpgradeable is ReentrancyGuardUpgradeable, ITokenReceivable {
    using SafeERC20 for IERC20;

    /// @custom:storage-location erc7201:ferrum.storage.TokenReceivable
    struct TokenReceivableStorage {
        mapping(address => uint256) inventory;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.TokenReceivable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TokenReceivableStorageLocation = 0xe43e77c001b2404bab4012cf755ad2eb5b6c114c2ee85fab8d388b96b6294200;

    function _getTokenReceivableStorage() internal pure returns (TokenReceivableStorage storage $) {
        assembly {
            $.slot := TokenReceivableStorageLocation
        }
    }

    function inventory(address token) external view returns (uint) {
        return _getTokenReceivableStorage().inventory[token];
    }

    function __TokenReceivable_init(
    ) internal onlyInitializing {
        __ReentrancyGuard_init();
    }

    function syncInventory(address token) external override returns (uint) {
        return sync(token);
    }

    /**
     @notice Sync the inventory of a token based on amount changed
     @param token The token address
     @return amount The changed amount
    */
    function sync(address token) internal nonReentrant returns (uint256 amount) {
        TokenReceivableStorage storage $ = _getTokenReceivableStorage();
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
    function sendToken(address token, address payee, uint256 amount) internal nonReentrant {
        TokenReceivableStorage storage $ = _getTokenReceivableStorage();
        $.inventory[token] -= amount;
        IERC20(token).safeTransfer(payee, amount);
    }
}