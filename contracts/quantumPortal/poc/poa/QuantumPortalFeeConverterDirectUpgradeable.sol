// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable, UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {WithAdminUpgradeable} from "foundry-contracts/contracts/contracts-upgradeable/common/WithAdminUpgradeable.sol";
import {IQuantumPortalFeeConvertor} from "./IQuantumPortalFeeConvertor.sol";
import "hardhat/console.sol";


/**
 * @notice Direct fee convertor for QP. The fee should be update by a trusted third party regularly
 */
contract QuantumPortalFeeConverterDirectUpgradeable is
    IQuantumPortalFeeConvertor,
    Initializable,
    UUPSUpgradeable,
    WithAdminUpgradeable
{
    string public constant VERSION = "000.001";

    /// @custom:storage-location erc7201:ferrum.storage.quantumportalfeeconverterdirect.001
    struct QuantumPortalFeeConverterDirectStorageV001 {
        address qpFeeToken;
        uint256 feePerByte;
        mapping(uint256 => uint256) feeTokenPriceList;
        mapping(uint256 => uint256) targetChainGasPriceList;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.quantumportalfeeconverterdirect.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant QuantumPortalFeeConverterDirectStorageV001Location = 0x1bb5efccb3fe848156cfca94d479e33ae6d3f05bb5c87d9f9eee341398fc7500;

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    function qpFeeToken() external view returns (address) {
        QuantumPortalFeeConverterDirectStorageV001 storage $ = _getQuantumPortalFeeConverterDirectStorageV001();
        return $.qpFeeToken;
    }

    function feePerBytes() external view returns (uint256) {
        return _getQuantumPortalFeeConverterDirectStorageV001().feePerByte;
    }

    function feeTokenPriceList(uint256 chainId) external view returns (uint256) {
        return _getQuantumPortalFeeConverterDirectStorageV001().feeTokenPriceList[chainId];
    }

    function targetChainGasPriceList(uint256 chainId) external view returns (uint256) {
        return _getQuantumPortalFeeConverterDirectStorageV001().targetChainGasPriceList[chainId];
    }

    function initialize(address initialOwnerAdmin) public initializer {
        __WithAdmin_init(initialOwnerAdmin, initialOwnerAdmin);
        __UUPSUpgradeable_init();
    }

    /**
     * Restricted. Update the fee per byte number
     * Note: When updating fpb on Eth network, remember FRM has only 6 decimals there
     * @param fpb The fee per byte
     */
    function updateFeePerByteX128(uint256 fpb) external onlyAdmin {
        _getQuantumPortalFeeConverterDirectStorageV001().feePerByte = fpb;
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
        QuantumPortalFeeConverterDirectStorageV001 storage $ = _getQuantumPortalFeeConverterDirectStorageV001();
        uint price = $.feeTokenPriceList[block.chainid];
        if (price == 0) {
            return 1;
        }
        return price;
    }

    /**
     * @notice Sets the local chain gas token price.
     */
    function setChainGasPricesX128(
        uint256[] memory chainIds,
        uint256[] memory nativeTokenPricesX128,
        uint256[] memory gasPricesX128
    ) external onlyAdmin {
        QuantumPortalFeeConverterDirectStorageV001 storage $ = _getQuantumPortalFeeConverterDirectStorageV001();
        require(chainIds.length == nativeTokenPricesX128.length, "QPFCD: Invalid args");
        require(chainIds.length == gasPricesX128.length, "QPFCD: Invalid args");
        for(uint i=0; i<chainIds.length; i++) {
            uint256 nativePrice = nativeTokenPricesX128[i];
            uint256 gasPrice = gasPricesX128[i];
            require(nativePrice != 0, "QPFCD: native price is zero");
            require(gasPrice != 0, "QPFCD: fee price is zero");
            $.feeTokenPriceList[chainIds[i]] = nativePrice;
            $.targetChainGasPriceList[chainIds[i]] = gasPrice;
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
        return _fixedFee(size);
    }

    function targetChainGasFee(
        uint256 targetChainId,
        uint256 gasLimit
    ) external view returns (uint256) {
        return _targetChainGasFee(targetChainId, gasLimit);
    }

    function targetChainFee(
        uint256 targetChainId,
        uint256 size,
        uint256 gasLimit
    ) external view returns (uint256) {
        return _fixedFee(size) + _targetChainGasFee(targetChainId, gasLimit);
    }

    function _fixedFee(
        uint256 size
    ) internal view returns (uint256) {
        QuantumPortalFeeConverterDirectStorageV001 storage $ = _getQuantumPortalFeeConverterDirectStorageV001();
        return size * $.feePerByte;
    }

    function _targetChainGasFee(
        uint256 targetChainId,
        uint256 gasLimit
    ) internal view returns (uint256) {
        QuantumPortalFeeConverterDirectStorageV001 storage $ = _getQuantumPortalFeeConverterDirectStorageV001();
        return gasLimit * $.targetChainGasPriceList[targetChainId] * _targetChainGasTokenPriceX128(targetChainId);
    }

    /**
     * @notice Return the gas token (FRM) price for the target chain
     * @param targetChainId The target chain ID
     */
    function _targetChainGasTokenPriceX128(
        uint256 targetChainId
    ) internal view returns (uint256) {
        QuantumPortalFeeConverterDirectStorageV001 storage $ = _getQuantumPortalFeeConverterDirectStorageV001();
        return $.feeTokenPriceList[targetChainId];
    }

    function _getQuantumPortalFeeConverterDirectStorageV001() internal pure returns (QuantumPortalFeeConverterDirectStorageV001 storage $) {
        assembly {
            $.slot := QuantumPortalFeeConverterDirectStorageV001Location
        }
    }
}
