// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./IQuantumPortalFeeConvertor.sol";
import "../../../fee/IPriceOracle.sol";
import "foundry-contracts/contracts/common/WithAdmin.sol";
import "foundry-contracts/contracts/common/IFerrumDeployer.sol";
import "foundry-contracts/contracts/math/FixedPoint128.sol";

import "hardhat/console.sol";

/**
 * @notice Fee convertor utility for QP. Used for gas calculations
 */
contract QuantumPortalFeeConverter is IQuantumPortalFeeConvertor, WithAdmin {
    address public override qpFeeToken;
    address public networkFeeWrappedToken;
    IPriceOracle oracle;
    mapping(uint256 => address) public targetNetworkFeeTokens;
    uint256 public feePerByte;

    constructor() {
        (
            address _networkFeeWrappedToken,
            address _qpFeeToken,
            address _oracle
        ) = abi.decode(
                IFerrumDeployer(msg.sender).initData(),
                (address, address, address)
            );
        networkFeeWrappedToken = _networkFeeWrappedToken;
        qpFeeToken = _qpFeeToken;
        oracle = IPriceOracle(_oracle);
    }

    /**
     * Restricted. Update the fee per byte number
     * Note: When you are setting the fbp on the ETH network, remember FRM has only 6 decimals there
     * @param fpb The fee per byte
     */
    function updateFeePerByte(uint256 fpb) external onlyAdmin {
        feePerByte = fpb;
    }

    /**
     * Fetch the price from the registered oracle
     */
    function updatePrice() external override {
        address[] memory pairs = new address[](2);
        pairs[0] = networkFeeWrappedToken;
        pairs[1] = qpFeeToken;
        oracle.updatePrice(pairs);
    }

    /**
     * @notice Return the gas token (FRM) price for the local chain
     */
    function localChainGasTokenPriceX128()
        external
        view
        override
        returns (uint256)
    {
        address[] memory pairs = new address[](2);
        pairs[0] = networkFeeWrappedToken;
        pairs[1] = qpFeeToken;
        console.log("PAIR", pairs[0], pairs[1]);
        return oracle.recentPriceX128(pairs);
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
        return (price * size * feePerByte) / FixedPoint128.Q128;
    }

    /**
     * @notice Return the gas token (FRM) price for the target chain
     * @param targetChainId The target chain ID
     */
    function _targetChainGasTokenPriceX128(
        uint256 targetChainId
    ) internal view returns (uint256) {
        address targetNetworkFeeToken = targetNetworkFeeTokens[targetChainId];
        require(
            targetNetworkFeeToken != address(0),
            "QPFC: No target chain token"
        );
        address[] memory pairs = new address[](2);
        pairs[0] = targetNetworkFeeToken;
        pairs[1] = qpFeeToken;
        console.log("PAIR", pairs[0], pairs[1]);
        return oracle.recentPriceX128(pairs);
    }
}
