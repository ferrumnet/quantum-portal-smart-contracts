// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./IQuantumPortalWorkPoolClient.sol";
import "foundry-contracts/contracts/math/FullMath.sol";
import "foundry-contracts/contracts/common/SafeAmount.sol";
import "./QuantumPortalWorkPoolServer.sol";

import "hardhat/console.sol";

/**
 * @notice Record amount of work done, and distribute rewards accordingly
 */
abstract contract QuantumPortalWorkPoolClient is IQuantumPortalWorkPoolClient, QuantumPortalWorkerBase {
    mapping (uint256=>mapping(address=>uint256)) public works; // Work done on remote chain
    mapping (uint256=>uint256) public totalWork; // Total work on remote chain
    mapping (uint256=>uint256) public remoteEpoch;

    function registerWork(uint256 remoteChain, address worker, uint256 work, uint256 _remoteEpoch) external override {
        require(msg.sender == mgr, "QPWPC: caller not allowed");
        works[remoteChain][worker] += work;
        totalWork[remoteChain] += work;
        remoteEpoch[remoteChain] = _remoteEpoch;
    }

    function withdraw(bytes4 selector, uint256 remoteChain, address worker, uint fee) internal {
        uint256 work = works[remoteChain][worker];
        works[remoteChain][worker] = 0;
        // Send the fee
        require(SafeAmount.safeTransferFrom(portal.feeToken(), msg.sender, portal.feeTarget(), fee) != 0, "QPWPC: fee required");
        uint256 workRatioX128 = FullMath.mulDiv(work, FixedPoint128.Q128, totalWork[remoteChain]); 
        uint256 epoch = remoteEpoch[remoteChain];
        bytes memory method = abi.encodeWithSelector(selector, worker, workRatioX128, epoch);
        address serverContract = remotes[remoteChain];
        portal.run(uint64(remoteChain), serverContract, msg.sender, method);
        // TODO: Challenge: What if the withdraw failed! Need a revert option
    }
}