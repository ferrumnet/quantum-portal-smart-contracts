// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


/**
 * @notice Contract for gateway access control
 */
abstract contract WithGateway is Initializable, OwnableUpgradeable {
    /// @custom:storage-location erc7201:ferrum.storage.withgateway.001
    struct WithGatewayStorageV001 {
        address gateway;
    }
    
    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.withgateway.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant WithGatewayStorageV001Location = 0xadb0729438189cf9f802e36d5668d64de8f56c3889aa3a2c6e67607aa5ec2e00;

    modifier onlyGateway() {
        require(msg.sender == _getWithGatewayStorageV001().gateway, "QPWG:only QP gateway may call");
        _;
    }

    function __WithGateway_init(address initialOwner, address _gateway) internal onlyInitializing {
        __Ownable_init(initialOwner);
        __WithGateway_init_unchained(_gateway);
    }

    function __WithGateway_init_unchained(address _gateway) internal onlyInitializing {
        _setGateway(_gateway);
    }

    function _getWithGatewayStorageV001() internal pure returns (WithGatewayStorageV001 storage $) {
        assembly {
            $.slot := WithGatewayStorageV001Location
        }
    }

    function gateway() public view returns (address) {
        return _getWithGatewayStorageV001().gateway;
    }

    /**
     * @notice Upddates the qp gateway address
     * @param _gateway the gateway
     */
    function updateGateway(address _gateway) external onlyOwner {
        _setGateway(_gateway);
    }

    function _setGateway(address _gateway) internal {
        WithGatewayStorageV001 storage $ = _getWithGatewayStorageV001();
        $.gateway = _gateway;
    }
}
