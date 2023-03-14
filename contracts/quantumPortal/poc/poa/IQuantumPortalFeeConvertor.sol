// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IQuantumPortalFeeConvertor {
    function localChainGasTokenPriceX128() external returns (uint256);
}