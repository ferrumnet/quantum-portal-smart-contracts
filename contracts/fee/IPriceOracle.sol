// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriceOracle {
    enum EmaType {
        _1Min, _1Hour, _1Day, _25Day, _50Day, _100Day
    }

    function updatePrice(address[] calldata path) external returns (bool);
    function recentPriceX128(address[] calldata path) external view returns (uint256);
    function emaX128(address[] calldata path, EmaType emaType) external view returns (uint256);
}