// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable, UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {FixedPoint128} from "foundry-contracts/contracts/contracts/math/FixedPoint128.sol";
import {WithAdminUpgradeable} from "foundry-contracts/contracts/contracts-upgradeable/common/WithAdminUpgradeable.sol";
import {WithGatewayUpgradeable} from "../utils/WithGatewayUpgradeable.sol";
import {IPriceOracle} from "../../../../fee/IPriceOracle.sol";


/**
 * @notice Fee convertor utility for QP. Used for gas calculations
 */
contract QuantumPortalFeeConverterUpgradeable is Initializable, UUPSUpgradeable, WithAdminUpgradeable, WithGatewayUpgradeable {
    string public constant VERSION = "0.0.1";

    /// @custom:storage-location erc7201:ferrum.storage.quantumportalfeeconverter.001
    struct QuantumPortalFeeConverterStorageV001 {
        address qpFeeToken;
        address networkFeeWrappedToken;
        uint256 feePerByte;
        mapping(uint256 => address) targetNetworkFeeTokens;
        IPriceOracle oracle;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.quantumportalfeeconverter.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant QuantumPortalFeeConverterStorageV001Location = 0xaba0b53a9265323e2d929e5915afa443008841d14c0632881afa3ef9dbea6d00;

    function _authorizeUpgrade(address newImplementation) internal override onlyGateway {}

    function _getQuantumPortalFeeConverterStorageV001() internal pure returns (QuantumPortalFeeConverterStorageV001 storage $) {
        assembly {
            $.slot := QuantumPortalFeeConverterStorageV001Location
        }
    }

    function initialize(
        address _networkFeeWrappedToken,
        address _qpFeeToken,
        address _oracle,
        address gateway,
        address initialOwnerAdmin
    ) public initializer {
        __WithAdmin_init(initialOwnerAdmin, initialOwnerAdmin);
        __WithGateway_init_unchained(gateway);
        __QuantumPortalFeeConvertor_init_unchained(_networkFeeWrappedToken, _qpFeeToken, _oracle);
    }

    function __QuantumPortalFeeConvertor_init_unchained(
        address _networkFeeWrappedToken,
        address _qpFeeToken,
        address _oracle
    ) internal onlyInitializing{
        QuantumPortalFeeConverterStorageV001 storage $ = _getQuantumPortalFeeConverterStorageV001();
        $.networkFeeWrappedToken = _networkFeeWrappedToken;
        $.qpFeeToken = _qpFeeToken;
        $.oracle = IPriceOracle(_oracle);
    }

    function qpFeeToken() external view returns (address) {
        QuantumPortalFeeConverterStorageV001 storage $ = _getQuantumPortalFeeConverterStorageV001();
        return $.qpFeeToken;
    }

    function networkFeeWrappedToken() external view returns (address) {
        QuantumPortalFeeConverterStorageV001 storage $ = _getQuantumPortalFeeConverterStorageV001();
        return $.networkFeeWrappedToken;
    }

    function targetNetworkFeeTokens(uint256 targetChainId) external view returns (address) {
        QuantumPortalFeeConverterStorageV001 storage $ = _getQuantumPortalFeeConverterStorageV001();
        return $.targetNetworkFeeTokens[targetChainId];
    }

    function feePerByte() external view returns (uint256) {
        QuantumPortalFeeConverterStorageV001 storage $ = _getQuantumPortalFeeConverterStorageV001();
        return $.feePerByte;
    }

    /**
     * Restricted. Update the fee per byte number
     * Note: When you are setting the fbp on the ETH network, remember FRM has only 6 decimals there
     * @param fpb The fee per byte
     */
    function updateFeePerByte(uint256 fpb) external onlyAdmin {
        QuantumPortalFeeConverterStorageV001 storage $ = _getQuantumPortalFeeConverterStorageV001();
        $.feePerByte = fpb;
    }

    /**
     * Fetch the price from the registered oracle
     */
    function updatePrice() external {
        QuantumPortalFeeConverterStorageV001 storage $ = _getQuantumPortalFeeConverterStorageV001();
        address[] memory pairs = new address[](2);
        pairs[0] = $.networkFeeWrappedToken;
        pairs[1] = $.qpFeeToken;
        $.oracle.updatePrice(pairs);
    }

    /**
     * @notice Return the gas token (FRM) price for the local chain
     */
    function localChainGasTokenPriceX128()
        external
        view
        returns (uint256)
    {
        QuantumPortalFeeConverterStorageV001 storage $ = _getQuantumPortalFeeConverterStorageV001();
        address[] memory pairs = new address[](2);
        pairs[0] = $.networkFeeWrappedToken;
        pairs[1] = $.qpFeeToken;
        return $.oracle.recentPriceX128(pairs);
    }

    /**
     * @notice Return the gas token (FRM) price for the target chain
     * @param targetChainId The target chain ID
     */
    function targetChainGasTokenPriceX128(
        uint256 targetChainId
    ) external view returns (uint256) {
        return _targetChainGasTokenPriceX128(targetChainId);
    }

    /**
     * @notice Get the fee for the target network
     */
    function targetChainFixedFee(
        uint256 targetChainId,
        uint256 size
    ) external view returns (uint256) {
        QuantumPortalFeeConverterStorageV001 storage $ = _getQuantumPortalFeeConverterStorageV001();
        uint256 price = _targetChainGasTokenPriceX128(targetChainId);
        return (price * size * $.feePerByte) / FixedPoint128.Q128;
    }

    /**
     * @notice Return the gas token (FRM) price for the target chain
     * @param targetChainId The target chain ID
     */
    function _targetChainGasTokenPriceX128(
        uint256 targetChainId
    ) internal view returns (uint256) {
        QuantumPortalFeeConverterStorageV001 storage $ = _getQuantumPortalFeeConverterStorageV001();
        address targetNetworkFeeToken = $.targetNetworkFeeTokens[targetChainId];
        require(
            targetNetworkFeeToken != address(0),
            "QPFC: No target chain token"
        );
        address[] memory pairs = new address[](2);
        pairs[0] = targetNetworkFeeToken;
        pairs[1] = $.qpFeeToken;
        return $.oracle.recentPriceX128(pairs);
    }
}
