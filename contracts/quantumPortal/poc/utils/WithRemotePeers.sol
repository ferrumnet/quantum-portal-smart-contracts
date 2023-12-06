// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.0;

abstract contract WithRemotePeers is Ownable {
    mapping (uint256 => address) public remotePeers;

    /**
     * @notice Sets the remote contract peers for QP.
     * @param chainIds The list of chain IDs
     * @param remotes The list of contracts
     */
    function updateRemotePeers(uint256[] calldata chainIds, address[] calldata remotes
    ) external onlyOwner {
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
    ) external onlyOwner {
        for (uint i=0; i<chainIds.length; i++) {
            delete remotePeers[chainIds[i]];
        }
    }
}