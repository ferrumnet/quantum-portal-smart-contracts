// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable, UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {FixedPoint128} from "foundry-contracts/contracts/contracts/math/FixedPoint128.sol";
import {WithAdmin} from "foundry-contracts/contracts/contracts-upgradeable/common/WithAdmin.sol";
import {IQuantumPortalFeeConvertor} from "../../../../quantumPortal/poc/poa/IQuantumPortalFeeConvertor.sol";


/**
 * @notice Direct fee convertor for QP. The fee should be update by a trusted third party regularly
 */
contract QuantumPortalFeeConverterDirect is IQuantumPortalFeeConvertor, Initializable, UUPSUpgradeable, WithAdmin {
    string public constant VERSION = "0.0.1";
    uint constant DEFAULT_PRICE = 0x100000000000000000000000000000000; //FixedPoint128.Q128;

    /// @custom:storage-location erc7201:ferrum.storage.quantumportalfeeconverterdirect.001
    struct QuantumPortalFeeConverterDirectStorageV001 {
        address qpFeeToken;
        uint256 feePerByte;
        mapping(uint256 => uint256) feeTokenPriceList;
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

    function initialize() public initializer {
        __WithAdmin_init(msg.sender, msg.sender);
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
    function localChainGasTokenPriceX128()
        external
        view
        override
        returns (uint256)
    {
        QuantumPortalFeeConverterDirectStorageV001 storage $ = _getQuantumPortalFeeConverterDirectStorageV001();
        uint price = $.feeTokenPriceList[block.chainid];
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
        QuantumPortalFeeConverterDirectStorageV001 storage $ = _getQuantumPortalFeeConverterDirectStorageV001();
        require(chainIds.length == pricesX128.length, "QPFCD: Invalid args");
        for(uint i=0; i<chainIds.length; i++) {
            uint256 price = pricesX128[i];
            require(price != 0, "QPFCD: price is zero");
            $.feeTokenPriceList[chainIds[i]] = price;
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
        QuantumPortalFeeConverterDirectStorageV001 storage $ = _getQuantumPortalFeeConverterDirectStorageV001();
        uint256 price = _targetChainGasTokenPriceX128(targetChainId);
        if (price == 0) {
            price = DEFAULT_PRICE;
        }
        return (price * size * $.feePerByte) / FixedPoint128.Q128;
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
