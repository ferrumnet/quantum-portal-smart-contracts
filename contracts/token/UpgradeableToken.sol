// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract UpgradeableToken is
    Initializable, 
    UUPSUpgradeable,
    OwnableUpgradeable,
    ERC20BurnableUpgradeable
{
    function _init(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address balanceHolder,
        address initOwner
    ) internal onlyInitializing {
        __ERC20_init(name, symbol);
        __ERC20Burnable_init();
        __UUPSUpgradeable_init();
        __Ownable_init(initOwner);
        _mint(balanceHolder, initialSupply);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

contract QpFerrumTokenUpgradeable is UpgradeableToken {
    function initialize(address initOwner, address balanceHolder) public virtual initializer {
        UpgradeableToken._init(
            "Ferrum Quantum Portal Network Token",
            "qpFRM",
            20_000_000 * 10 ** 18,
            balanceHolder,
            initOwner);
    }
}
