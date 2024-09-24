// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IUUPSUpgradeable {
    function upgradeToAndCall(address newImplementation, bytes calldata data) external;
}
