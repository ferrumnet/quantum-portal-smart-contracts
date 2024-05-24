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
    string public constant VERSION = "0.0.1";
    uint constant DEFAULT_PRICE = 0x100000000000000000000000000000000; //FixedPoint128.Q128;
    address public override qpFeeToken;
    uint256 public feePerByte;
    mapping (uint256 => uint256) public feeTokenPriceList;

    constructor() Ownable(msg.sender) {}

    /**
     * Restricted. Update the fee per byte number
     * Note: When updating fpb on Eth network, remember FRM has only 6 decimals there
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
     * @notice Return the gas token (FRM) price for the local chain.
     */
    function localChainGasTokenPriceX128()
        external
        view
        override
        returns (uint256)
    {
        uint price = feeTokenPriceList[block.chainid];
        if (price == 0) {
            return DEFAULT_PRICE;
        }
        return price;
    }

    /**
     * @notice Sets the local chain gas token price.
     */
    function setChainGasTokenPriceX128(
        uint256[] memory chainIds,
        uint256[] memory pricesX128
    ) external onlyAdmin {
        require(chainIds.length == pricesX128.length, "QPFCD: Invalid args");
        for(uint i=0; i<chainIds.length; i++) {
            uint256 price = pricesX128[i];
            require(price != 0, "QPFCD: price is zero");
            feeTokenPriceList[chainIds[i]] = price;
        }
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
     * @notice Get the fee for the target network
     */
    function targetChainFixedFee(
        uint256 targetChainId,
        uint256 size
    ) external view override returns (uint256) {
        uint256 price = _targetChainGasTokenPriceX128(targetChainId);
        if (price == 0) {
            price = DEFAULT_PRICE;
        }
        console.log("CALCING FEE PER BYTE", price, targetChainId);
        return (price * size * feePerByte) / FixedPoint128.Q128;
    }

    /**
     * @notice Return the gas token (FRM) price for the target chain
     * @param targetChainId The target chain ID
     */
    function _targetChainGasTokenPriceX128(
        uint256 targetChainId
    ) internal view returns (uint256) {
        return feeTokenPriceList[targetChainId];
    }
}
