// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "foundry-contracts/contracts/common/WithAdmin.sol";

abstract contract QuantumPortalWorkerBase is WithAdmin {
    /**
     * @notice Limit access to only mgr
     */
    modifier onlyMgr() {
        require(msg.sender == mgr, "QPWPS:only QP mgr may call");
        _;
    }

    mapping(uint256 => address) public remotes;
    IQuantumPortalPoc public portal;
    address public mgr;

    /**
     * @notice Restricted: Sets the remote address
     * @param chainId The remote chain ID
     * @param remote The remote contract address
     */
    function setRemote(uint256 chainId, address remote) external onlyAdmin {
        remotes[chainId] = remote;
    }
}
