// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./IQuantumPortalFeeConvertor.sol";
import "../../../fee/IPriceOracle.sol";
import "foundry-contracts/contracts/common/IFerrumDeployer.sol";

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

    function localChainGasTokenPriceX128() external override returns (uint256) {
        address[] memory pairs = new address[](2);
        pairs[0] = qpFeeToken;
        pairs[1] = networkFeeWrappedToken;
        oracle.updatePrice(pairs);
        return oracle.recentPriceX128(pairs);
    }
}