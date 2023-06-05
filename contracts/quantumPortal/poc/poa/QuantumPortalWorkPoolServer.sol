// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../IQuantumPortalPoc.sol";
import "./IQuantumPortalWorkPoolServer.sol";
import "foundry-contracts/contracts/math/FullMath.sol";
import "foundry-contracts/contracts/math/FixedPoint128.sol";
import "../../../staking/library/TokenReceivable.sol";
import "foundry-contracts/contracts/common/WithAdmin.sol";
import "hardhat/console.sol";

abstract contract QuantumPortalWorkerBase is WithAdmin {
    mapping(uint256=>address) public remotes;
    IQuantumPortalPoc public portal;
    address public mgr;
    function setRemote(uint256 chainId, address remote) external onlyAdmin {
        remotes[chainId] = remote;
    }
}

/**
 * @notice Collect and distribute rewards
 */
abstract contract QuantumPortalWorkPoolServer is IQuantumPortalWorkPoolServer, TokenReceivable, QuantumPortalWorkerBase {
    address public baseToken;
    mapping(uint256=>uint256) public lastEpoch;
    mapping(uint256=>uint256) public collectedFixedFee;
    mapping(uint256=>uint256) public collectedVarFee;

    function initServer(address _portal, address _mgr, address _baseToken) external onlyAdmin {
        portal = IQuantumPortalPoc(_portal);
        mgr = _mgr;
        baseToken = _baseToken;
    }

    function collectFee(uint256 targetChainId, uint256 localEpoch, uint256 fixedFee) external override returns (uint256 varFee) {
        require(msg.sender == mgr, "QPWPS:only QP mgr may call");
        uint256 collected = sync(baseToken);
        require(collected >= fixedFee, "QPWPS: Not enough fee");
        console.log("CollectFee EPOCH", localEpoch, targetChainId);
        lastEpoch[targetChainId] = localEpoch;
        collectedFixedFee[targetChainId] += fixedFee;
        varFee = collected - fixedFee;
        collectedVarFee[targetChainId] += varFee;
    }

    function withdrawFixedRemote(address worker, uint256 workRatioX128, uint256 epoch) external override {
        console.log("WITHDRAW_FIXED_REMOTE", worker);
        console.log("workRatio", workRatioX128);
        console.log("epoch", epoch);
        (uint256 remoteChainId, uint256 lastLocalEpoch) = withdrawRemote(epoch);
        uint collected = FullMath.mulDiv(collectedFixedFee[remoteChainId], epoch, lastLocalEpoch);
        uint amount = FullMath.mulDiv(collected, workRatioX128, FixedPoint128.Q128); 
        amount = amount;
        collectedFixedFee[remoteChainId] -= amount;
        console.log("WITHDRAW CALLED HERE", worker, amount);
        sendToken(baseToken, worker, amount);
    }

    function withdrawVariableRemote(address worker, uint256 workRatioX128, uint256 epoch) external override {
        (uint256 remoteChainId, uint256 lastLocalEpoch) = withdrawRemote(epoch);
        uint collected = FullMath.mulDiv(collectedVarFee[remoteChainId], epoch, lastLocalEpoch);
        uint amount = FullMath.mulDiv(collected, workRatioX128, FixedPoint128.Q128); 
        collectedVarFee[remoteChainId] -= amount;
        sendToken(baseToken, worker, amount);
    }

    function withdrawRemote(uint256 epoch) internal view returns (uint256, uint256) {
        (uint256 remoteChainId, address sourceMsgSender, /* address beneficiary */) = portal.msgSender();
        // Caller must be a valid pre-configured remote.
        require(sourceMsgSender == remotes[remoteChainId], "Not allowed"); 
        // Worker gets the same ratio of fees compared to the collected fees.
        uint lastLocalEpoch = lastEpoch[remoteChainId]; // Note: This can NOT be zero
        console.log("LAST LOCAL EPOCH IS VS", lastEpoch[remoteChainId], remoteChainId);
        require(epoch <= lastLocalEpoch, "QPWPS:expected epoch<=lastLocalEpoch");
        return (remoteChainId, lastLocalEpoch);
    }
}