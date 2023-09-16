// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IQuantumPortalFeeConvertor {
    function updatePrice() external;

    function localChainGasTokenPriceX128() external returns (uint256);

    function targetChainGasTokenPriceX128(
        uint256 targetChainId
    ) external view returns (uint256);

    function targetChainFixedFee(
        uint256 targetChainId,
        uint256 size
    ) external view returns (uint256);

    function qpFeeToken() external returns (address);
}
