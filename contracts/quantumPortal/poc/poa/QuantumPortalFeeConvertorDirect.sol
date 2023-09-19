// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./IQuantumPortalFeeConvertor.sol";
import "foundry-contracts/contracts/math/FixedPoint128.sol";
import "foundry-contracts/contracts/common/WithAdmin.sol";

import "hardhat/console.sol";

/**
 * @notice Direct fee convertor for QP. The fee should be update by a trusted third party regularly
 */
contract QuantumPortalFeeConverterDirect is
    IQuantumPortalFeeConvertor,
    WithAdmin
{
    address public override qpFeeToken;
    uint256 public feePerByte;

    /**
     * Restricted. Update the fee per byte number
     * @param fpb The fee per byte
     */
    function updateFeePerByte(uint256 fpb) external onlyAdmin {
        feePerByte = fpb;
    }

    /**
     * @notice Unused
     */
    function updatePrice() external override {}

    /**
     * @notice Return the gas token (FRM) price for the local chain
     * TODO: Implement
     */
    function localChainGasTokenPriceX128()
        external
        pure
        override
        returns (uint256)
    {
        return FixedPoint128.Q128;
    }

    /**
     * @notice Return the gas token (FRM) price for the target chain
     * @param targetChainId The target chain ID
     */
    function targetChainGasTokenPriceX128(
        uint256 targetChainId
    ) external view override returns (uint256) {
        return _targetChainGasTokenPriceX128(targetChainId);
    }

    /**
     * @notice Return the gas token (FRM) price for the target chain
     *   TODO: Implement
     * @param targetChainId The target chain ID
     */
    function _targetChainGasTokenPriceX128(
        uint256 targetChainId
    ) internal view returns (uint256) {
        // TODO: set manually
        return FixedPoint128.Q128;
    }

    /**
     * @notice Get the fee for the target network
     */
    function targetChainFixedFee(
        uint256 targetChainId,
        uint256 size
    ) external view override returns (uint256) {
        uint256 price = _targetChainGasTokenPriceX128(targetChainId);
        console.log("CALCING FEE PER BYTE", price, targetChainId);
        return (price * size * feePerByte) / FixedPoint128.Q128;
    }
}
