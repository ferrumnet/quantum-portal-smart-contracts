// SPDX-License-Identifier: MIT
import "foundry-contracts/contracts/contracts/common/WithAdmin.sol";

pragma solidity ^0.8.0;

abstract contract WithRemotePeers is WithAdmin {
    mapping (uint256 => address) public remotePeers;

    /**
     * @notice Sets the remote contract peers for QP.
     * @param chainIds The list of chain IDs
     * @param remotes The list of contracts
     */
    function updateRemotePeers(uint256[] calldata chainIds, address[] calldata remotes
    ) external virtual onlyOwner {
        require(chainIds.length == remotes.length, "WRP: wrong no. of remotes");
        for (uint i=0; i<chainIds.length; i++) {
            require(remotes[i] != address(0), "WRP: remote is required");
            remotePeers[chainIds[i]] = remotes[i];
        }
    }

    /**
     * @notice Remove remote peers
     * @param chainIds The list of chain IDs
     */
    function removeRemotePeers(uint256[] calldata chainIds
    ) external virtual onlyOwner {
        for (uint i=0; i<chainIds.length; i++) {
            delete remotePeers[chainIds[i]];
        }
    }
}