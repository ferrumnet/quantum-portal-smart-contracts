// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriceOracle {
    enum EmaType {
        _1Min, _1Hour, _1Day, _25Day, _50Day, _100Day
    }

    /**
     * @notice Updates price for a path
     * @param path The path as it will be used in the AMM
     */
    function updatePrice(address[] calldata path) external returns (bool);

    /**
     * @notice Recent price encoded as fixed floating point.
     * @param path The path as it will be used in the AMM
     */
    function recentPriceX128(address[] calldata path) external view returns (uint256);

    /**
     * @notice Exponential moving average as fixed floating point.
     * @param path The path as it will be used in the AMM
     * @param emaType The `EmaType`. See the type definition.
     */
    function emaX128(address[] calldata path, EmaType emaType) external view returns (uint256);
}