// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IQuantumPortalFeeConvertor {

    /**
     * @notice Update the price. Call before getting the price
     */
    function updatePrice() external;

    /**
     * @notice Loal chain gas token price versus FRM
     * @return The token price
     */
    function localChainGasTokenPrice() external returns (uint256);

    /**
     * @notice Target chain gas token price versus FRM
     * @param targetChainId The target chain ID
     */
    function targetChainGasTokenPrice(
        uint256 targetChainId
    ) external view returns (uint256);

    /**
     * @notice Fixed fee in FRM for the target chain
     * @param size Data size
     * @return The fixed fee required
     */
    function fixedFee(uint256 size) external view returns (uint256);

    /**
     * @notice The QP Fee Token address for the local chain (FRM)
     */
    function qpFeeToken() external returns (address);
}
