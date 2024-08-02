// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {WithAdmin} from "foundry-contracts/contracts/contracts-upgradeable/common/WithAdmin.sol";


abstract contract WithRemotePeers is WithAdmin {
    /// @custom:storage-location erc7201:ferrum.storage.withremotepeers.001
    struct WithRemotePeersStorageV001 {
        mapping(uint256 => address) remotePeers;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.withremotepeers.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant WithRemotePeersStorageV001Location = 0x0ab96aa66448c31dd08344c9c98c9fafd8a577423aa674bb178096874369fe00;
    
    function _getWithRemotePeersStorageV001() internal pure returns (WithRemotePeersStorageV001 storage $) {
        assembly {
            $.slot := WithRemotePeersStorageV001Location
        }
    }

    function remotePeers(uint256 chainId) public view returns (address) {
        return _getWithRemotePeersStorageV001().remotePeers[chainId];
    }

    /**
     * @notice Sets the remote contract peers for QP.
     * @param chainIds The list of chain IDs
     * @param remotes The list of contracts
     */
    function updateRemotePeers(uint256[] calldata chainIds, address[] calldata remotes
    ) external virtual onlyOwner {
        WithRemotePeersStorageV001 storage $ = _getWithRemotePeersStorageV001();
        require(chainIds.length == remotes.length, "WRP: wrong no. of remotes");
        for (uint i=0; i<chainIds.length; i++) {
            require(remotes[i] != address(0), "WRP: remote is required");
            $.remotePeers[chainIds[i]] = remotes[i];
        }
    }

    /**
     * @notice Remove remote peers
     * @param chainIds The list of chain IDs
     */
    function removeRemotePeers(uint256[] calldata chainIds
    ) external virtual onlyOwner {
        WithRemotePeersStorageV001 storage $ = _getWithRemotePeersStorageV001();
        for (uint i=0; i<chainIds.length; i++) {
            delete $.remotePeers[chainIds[i]];
        }
    }
}
