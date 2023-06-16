// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IQuantumPortalPoc.sol";
import "foundry-contracts/contracts/common/IVersioned.sol";
import "../../staking/library/TokenReceivable.sol";
import "./PortalLedger.sol";
import "./QuantumPortalLib.sol";

abstract contract QuantumPortalPoc is TokenReceivable, PortalLedger, IQuantumPortalPoc, IVersioned {
	string constant public override VERSION = "000.001";
    address public override feeTarget;
    address public override feeToken;

    function setFeeTarget(address _feeTarget) external onlyAdmin {
        feeTarget = _feeTarget;
    }

    function setFeeToken(address _feeToken) external onlyAdmin {
        feeToken = _feeToken;
    }

    function txContext() external override view returns (QuantumPortalLib.Context memory) {
        return context;
    }

    /**
     @notice Registers a run in the local context. No value transfer
     */
    function run(uint64 remoteChainId, address remoteContract, address beneficiary, bytes memory remoteMethodCall) external override {
        require(remoteMethodCall.length != 0, "remoteMethodCall is required");
        require(remoteChainId != CHAIN_ID, "Remote cannot be self");
        IQuantumPortalLedgerMgr(mgr).registerTransaction(
            remoteChainId,
            remoteContract,
            msg.sender,
            beneficiary,
            address(0),
            0,
            remoteMethodCall);
    }

    /**
     @notice Runs a remote method and pays the token amount to the remote method.
     */
    function runWithValue(
        uint64 remoteChainId, address remoteContract, address beneficiary, address token, bytes memory method) external override {
        require(remoteChainId != CHAIN_ID, "Remote cannot be self");
        IQuantumPortalLedgerMgr(mgr).registerTransaction(
            remoteChainId,
            remoteContract,
            msg.sender,
            beneficiary,
            token,
            sync(token),
            method);
    }

    /**
     @notice Runs a remote withdraw. Mining this tx will update the balance for the user. User can then call a withdraw.
     */
    function runWithdraw(
        uint64 remoteChainId, address remoteAddress, address token, uint256 amount) external override {
        require(remoteChainId != CHAIN_ID, "Remote cannot be self");
        remoteBalances[remoteChainId][token][msg.sender] -= amount;
        IQuantumPortalLedgerMgr(mgr).registerTransaction(
            remoteChainId,
            remoteAddress,
            msg.sender,
            address(0),
            token,
            amount,
            "");
    }

    /**
     @notice Transfers the remote balance to another account
     */
    function remoteTransfer(uint256 chainId, address token, address to, uint256 amount) external override {
        require(msg.sender == context.transaction.remoteContract, "QPP: can only be called within a mining context");
        if (chainId == context.blockMetadata.chainId && token == context.transaction.token) {
            context.uncommitedBalance -= amount;
        } else {
            remoteBalances[chainId][token][msg.sender] -= amount;
        }
        remoteBalances[chainId][token][to] += amount;
    }

    function withdraw(address token, uint256 amount) external {
        require(context.blockMetadata.chainId == 0, "QPP: cannot be called within a mining context");
        uint256 bal = remoteBalances[CHAIN_ID][token][msg.sender];
        require(bal >= amount, "QPP: Not enough balance");
        remoteBalances[CHAIN_ID][token][msg.sender] = bal - amount;
        sendToken(token, msg.sender, amount);
    }

    /**
     @notice Returns the msgSender in the current context.
     */
    function msgSender() external view override returns (uint256 sourceNetwork, address sourceMsgSender, address sourceBeneficiary) {
        sourceNetwork = context.blockMetadata.chainId;
        sourceMsgSender = context.transaction.sourceMsgSender;
        sourceBeneficiary = context.transaction.sourceBeneficiary;
    }
}

contract QuantumPortalPocImpl is QuantumPortalPoc {
    constructor() PortalLedger(0) {}
}