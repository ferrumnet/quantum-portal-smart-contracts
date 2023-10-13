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
abstract contract QuantumPortalWorkPoolClient is
    IQuantumPortalWorkPoolClient,
    QuantumPortalWorkerBase
{
    mapping(uint256 => mapping(address => uint256)) public works; // Work done on remote chain
    mapping(uint256 => uint256) public totalWork; // Total work on remote chain
    mapping(uint256 => uint256) public remoteEpoch;

    /**
     * @notice Ristricted: update the manager
     * @param _mgr The manager contract address
     */
    function updateMgr(address _mgr) external onlyAdmin {
        mgr = _mgr;
    }

    /**
     * @inheritdoc IQuantumPortalWorkPoolClient
     */
    function registerWork(
        uint256 remoteChain,
        address worker,
        uint256 work,
        uint256 _remoteEpoch
    ) external override {
        require(msg.sender == mgr, "QPWPC: caller not allowed");
        works[remoteChain][worker] += work;
        console.log("REGISTERING WORK", worker, work);
        totalWork[remoteChain] += work;
        remoteEpoch[remoteChain] = _remoteEpoch;
    }

    /**
     * @notice Withdraw the rewards on the remote chain
     * @param selector The selector
     * @param remoteChain The remote
     * @param to Send the rewards to
     * @param worker The worker
     * @param fee The multi-chain transaction fee
     */
    function withdraw(
        bytes4 selector,
        uint256 remoteChain,
        address to,
        address worker,
        uint fee
    ) internal {
        uint256 work = works[remoteChain][worker];
        works[remoteChain][worker] = 0;
        // Send the fee
        require(
            SafeAmount.safeTransferFrom(
                portal.feeToken(),
                msg.sender,
                portal.feeTarget(),
                fee
            ) != 0,
            "QPWPC: fee required"
        );
        uint256 workRatioX128 = FullMath.mulDiv(
            work,
            FixedPoint128.Q128,
            totalWork[remoteChain]
        );
        uint256 epoch = remoteEpoch[remoteChain];
        bytes memory method = abi.encodeWithSelector(
            selector,
            to,
            workRatioX128,
            epoch
        );
        address serverContract = remotes[remoteChain];
        console.log("ABOUT TO CALL REMOTE WITHDRAW", serverContract);
        console.log("WORKER", worker, to);
        console.log("WORKE RATIO", work, workRatioX128);
        console.log("EPOCH", epoch);
        portal.run(uint64(remoteChain), serverContract, msg.sender, method);
        // TODO: Challenge: What if the withdraw failed! Need a revert option
    }
}
