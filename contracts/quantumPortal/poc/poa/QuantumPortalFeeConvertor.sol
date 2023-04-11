// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./IQuantumPortalFeeConvertor.sol";
import "../../../fee/IPriceOracle.sol";
import "foundry-contracts/contracts/common/IFerrumDeployer.sol";
import "hardhat/console.sol";

contract QuantumPortalFeeConverter is IQuantumPortalFeeConvertor {
    address networkFeeWrappedToken;
    address qpFeeToken;
    IPriceOracle oracle;
    
    constructor() {
		(address _networkFeeWrappedToken, address _qpFeeToken, address _oracle) = abi.decode(
            IFerrumDeployer(msg.sender).initData(), (address, address, address));
        networkFeeWrappedToken = _networkFeeWrappedToken;
        qpFeeToken = _qpFeeToken;
        oracle = IPriceOracle(_oracle);
    }

    function updatePrice() external override {
        address[] memory pairs = new address[](2);
        pairs[0] = networkFeeWrappedToken;
        pairs[1] = qpFeeToken;
        oracle.updatePrice(pairs);
    }

    function localChainGasTokenPriceX128() external view override returns (uint256) {
        address[] memory pairs = new address[](2);
        pairs[0] = networkFeeWrappedToken;
        pairs[1] = qpFeeToken;
        console.log("PAIR", pairs[0], pairs[1]);
        return oracle.recentPriceX128(pairs);
    }
}