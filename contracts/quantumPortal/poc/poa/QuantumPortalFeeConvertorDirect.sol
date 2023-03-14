// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./IQuantumPortalFeeConvertor.sol";

contract QuantumPortalFeeConverterDirect is IQuantumPortalFeeConvertor {
    function localChainGasTokenPriceX128() external pure override returns (uint256) {
        return 1;
    }
}