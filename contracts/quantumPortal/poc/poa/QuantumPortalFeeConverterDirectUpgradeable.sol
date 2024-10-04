// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable, UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {WithAdminUpgradeable} from "foundry-contracts/contracts/contracts-upgradeable/common/WithAdminUpgradeable.sol";
import {IQuantumPortalFeeConvertor} from "./IQuantumPortalFeeConvertor.sol";


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
        mapping(uint256 => ChainData) chainDataList;
    }

    struct ChainData {
        uint256 feeTokenPrice;
        uint128 gasPrice;
        bool isL2;
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

    function feeTokenPrice(uint256 chainId) external view returns (uint256) {
        return _getQuantumPortalFeeConverterDirectStorageV001().chainDataList[chainId].feeTokenPrice;
    }

    function targetChainGasPrice(uint256 chainId) external view returns (uint256) {
        return _getQuantumPortalFeeConverterDirectStorageV001().chainDataList[chainId].gasPrice;
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
    function updateFeePerByte(uint256 fpb) external onlyAdmin {
        _getQuantumPortalFeeConverterDirectStorageV001().feePerByte = fpb;
    }

    /**
     * @notice Unused
     */
    function updatePrice() external override {}

    /**
     * @notice Return the gas token (FRM) price for the local chain.
     */
    function localChainGasTokenPrice()
        external
        view
        override
        returns (uint256)
    {
        QuantumPortalFeeConverterDirectStorageV001 storage $ = _getQuantumPortalFeeConverterDirectStorageV001();
        uint price = $.chainDataList[block.chainid].feeTokenPrice;
        if (price == 0) {
            return 1;
        }
        return price;
    }

    /**
     * @notice Sets the local chain gas token price.
     */
    function setChainGasPrices(
        uint256[] memory chainIds,
        uint256[] memory feeTokenPrices,
        uint128[] memory gasPrices,
        bool[] memory isL2
    ) external onlyAdmin {
        QuantumPortalFeeConverterDirectStorageV001 storage $ = _getQuantumPortalFeeConverterDirectStorageV001();
        require(chainIds.length == feeTokenPrices.length, "QPFCD: Invalid args");
        require(chainIds.length == gasPrices.length, "QPFCD: Invalid args");
        for(uint i=0; i<chainIds.length; i++) {
            require(feeTokenPrices[i] != 0, "QPFCD: native price is zero");
            require(gasPrices[i] != 0, "QPFCD: fee price is zero");
            $.chainDataList[chainIds[i]].feeTokenPrice = feeTokenPrices[i];
            $.chainDataList[chainIds[i]].gasPrice = gasPrices[i];
            $.chainDataList[chainIds[i]].isL2 = isL2[i];
        }
    }

    /**
     * @notice Return the gas token (FRM) price for the target chain
     * @param targetChainId The target chain ID
     */
    function targetChainGasTokenPrice(
        uint256 targetChainId
    ) external view override returns (uint256) {
        return _targetChainGasTokenPrice(targetChainId);
    }

    /**
     * @notice Get the fee for the target network
     */
    function fixedFee(uint256 size) external view override returns (uint256) {
        return _fixedFee(size);
    }

    function targetChainGasFee(
        uint256 targetChainId,
        uint256 gasLimit,
        uint256 size
    ) external view returns (uint256) {
        return _targetChainGasFee(targetChainId, gasLimit, size);
    }

    function targetChainFee(
        uint256 targetChainId,
        uint256 gasLimit,
        uint256 size
    ) external view returns (uint256) {
        return _fixedFee(size) + _targetChainGasFee(targetChainId, gasLimit, size);
    }

    function fixedFeeNative(uint256 size) external view returns (uint256) {
        return _fixedFeeNative(size);
    }

    function targetChainGasFeeNative(
        uint256 targetChainId,
        uint256 gasLimit,
        uint256 size
    ) external view returns (uint256) {
        return _targetChainGasFeeNative(targetChainId, gasLimit, size);
    }

    function targetChainFeeNative(
        uint256 targetChainId,
        uint256 gasLimit,
        uint256 size
    ) external view returns (uint256) {
        return _fixedFeeNative(size) + _targetChainGasFeeNative(targetChainId, gasLimit, size);
    }

    function _fixedFee(
        uint256 size
    ) internal view returns (uint256) {
        QuantumPortalFeeConverterDirectStorageV001 storage $ = _getQuantumPortalFeeConverterDirectStorageV001();
        return size * $.feePerByte;
    }

    function _targetChainGasFee(
        uint256 targetChainId,
        uint256 gasLimit,
        uint256 size
    ) internal view returns (uint256) {
        QuantumPortalFeeConverterDirectStorageV001 storage $ = _getQuantumPortalFeeConverterDirectStorageV001();
        uint256 executionCost = gasLimit * $.chainDataList[targetChainId].gasPrice * _targetChainGasTokenPrice(targetChainId);
        
        if (!$.chainDataList[targetChainId].isL2) {
            return executionCost;
        } else {
            // Use an approximation for this
            uint256 l1GasPrice = $.chainDataList[1].gasPrice;
            require(l1GasPrice != 0, "QPFCD: L1 gas price not set");
            uint256 l1Cost = ((256 + size) * 16) * l1GasPrice;
            return executionCost + l1Cost;
        }
    }

    /**
     * @notice Return the gas token (FRM) price for the target chain
     * @param targetChainId The target chain ID
     */
    function _targetChainGasTokenPrice(
        uint256 targetChainId
    ) internal view returns (uint256) {
        QuantumPortalFeeConverterDirectStorageV001 storage $ = _getQuantumPortalFeeConverterDirectStorageV001();
        return $.chainDataList[targetChainId].feeTokenPrice;
    }

    function _fixedFeeNative(
        uint256 size
    ) internal view returns (uint256) {
        QuantumPortalFeeConverterDirectStorageV001 storage $ = _getQuantumPortalFeeConverterDirectStorageV001();
        return _fixedFee(size) / $.chainDataList[block.chainid].feeTokenPrice;
    }

    function _targetChainGasFeeNative(
        uint256 targetChainId,
        uint256 gasLimit,
        uint256 size
    ) internal view returns (uint256) {
        QuantumPortalFeeConverterDirectStorageV001 storage $ = _getQuantumPortalFeeConverterDirectStorageV001();
        return _targetChainGasFee(targetChainId, gasLimit, size) / $.chainDataList[block.chainid].feeTokenPrice;
    }

    function _getQuantumPortalFeeConverterDirectStorageV001() internal pure returns (QuantumPortalFeeConverterDirectStorageV001 storage $) {
        assembly {
            $.slot := QuantumPortalFeeConverterDirectStorageV001Location
        }
    }

    function _isL2(uint256 chainId) internal pure returns (bool) {
        return chainId != 1;
    }
}
