// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ITokenReceivable {
    function syncInventory(address token) external returns (uint);
}