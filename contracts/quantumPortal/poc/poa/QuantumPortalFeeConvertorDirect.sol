// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./IQuantumPortalFeeConvertor.sol";
import "foundry-contracts/contracts/math/FixedPoint128.sol";

contract QuantumPortalFeeConverterDirect is IQuantumPortalFeeConvertor {
    address public override qpFeeToken;
    uint256 public feePerByte;

    function updatePrice() external override { }

    function localChainGasTokenPriceX128() external pure override returns (uint256) {
        return 1;
    }

    function targetChainGasTokenPriceX128(uint256 targetChainId) external view override returns (uint256) {
        return _targetChainGasTokenPriceX128(targetChainId);
    }

    function _targetChainGasTokenPriceX128(uint256 targetChainId) internal view returns (uint256) {
        // TODO: set manually
        return 1;
    }

    function targetChainFixedFee(uint256 targetChainId, uint256 size) external override view returns (uint256) {
        uint256 price = _targetChainGasTokenPriceX128(targetChainId);
        return price * size * feePerByte / FixedPoint128.Q128;
    }
}