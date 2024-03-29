// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IQuantumPortalPoc.sol";
import "foundry-contracts/contracts/common/IVersioned.sol";
import "../../staking/library/TokenReceivable.sol";
import "./PortalLedger.sol";
import "./QuantumPortalLib.sol";

/**
 * @notice The quantum portal main contract for multi-chain dApps
 */
abstract contract QuantumPortalPoc is
    TokenReceivable,
    PortalLedger,
    IQuantumPortalPoc,
    IVersioned
{
    event LocalTransfer(address token, address to, uint256 amount);

    string public constant override VERSION = "000.001";
    address public override feeTarget;
    address public override feeToken;

    /**
     * @notice Restricted: Set the fee target
     * @param _feeTarget The fee target
     */
    function setFeeTarget(address _feeTarget) external onlyAdmin {
        feeTarget = _feeTarget;
    }

    /**
     * @notice Ristricted: Sets the fee token
     * @param _feeToken The fee token
     */
    function setFeeToken(address _feeToken) external onlyAdmin {
        feeToken = _feeToken;
    }

    /**
     * @inheritdoc IQuantumPortalPoc
     */
    function txContext()
        external
        view
        override
        returns (QuantumPortalLib.Context memory)
    {
        return context;
    }

    /**
     * @inheritdoc IQuantumPortalPoc
     */
    function run(
        uint64 remoteChainId,
        address remoteContract,
        address beneficiary,
        bytes memory remoteMethodCall
    ) external override {
        require(remoteMethodCall.length != 0, "remoteMethodCall is required");
        require(remoteChainId != CHAIN_ID, "Remote cannot be self");
        IQuantumPortalLedgerMgr(mgr).registerTransaction(
            remoteChainId,
            remoteContract,
            msg.sender,
            beneficiary,
            address(0),
            0,
            remoteMethodCall
        );
    }

    /**
     * @inheritdoc IQuantumPortalPoc
     */
    function runWithValue(
        uint64 remoteChainId,
        address remoteContract,
        address beneficiary,
        address token,
        bytes memory method
    ) external override {
        require(remoteChainId != CHAIN_ID, "Remote cannot be self");
        IQuantumPortalLedgerMgr(mgr).registerTransaction(
            remoteChainId,
            remoteContract,
            msg.sender,
            beneficiary,
            token,
            sync(token),
            method
        );
    }

    /**
     * @inheritdoc IQuantumPortalPoc
     */
    function runWithdraw(
        uint64 remoteChainId,
        address remoteAddress,
        address token,
        uint256 amount
    ) external override {
        require(remoteChainId != CHAIN_ID, "Remote cannot be self");
        state.setRemoteBalances(
            remoteChainId,
            token,
            msg.sender,
            state.getRemoteBalances(remoteChainId, token, msg.sender) - amount
        );
        IQuantumPortalLedgerMgr(mgr).registerTransaction(
            remoteChainId,
            remoteAddress,
            msg.sender,
            address(0),
            token,
            amount,
            ""
        );
    }

    /**
     * @inheritdoc IQuantumPortalPoc
     */
    function remoteTransfer(
        uint256 chainId,
        address token,
        address to,
        uint256 amount
    ) external override {
        require(
            msg.sender == context.transaction.remoteContract,
            "QPP: can only be called within a mining context"
        );
        if (
            chainId == context.blockMetadata.chainId &&
            token == context.transaction.token
        ) {
            context.uncommitedBalance -= amount;
        } else {
            state.setRemoteBalances(
                chainId,
                token,
                msg.sender,
                state.getRemoteBalances(chainId, token, msg.sender) - amount
            );
        }
        state.setRemoteBalances(
            chainId,
            token,
            to,
            state.getRemoteBalances(chainId, token, to) + amount
        );
        emit RemoteTransfer(chainId, token, msg.sender, to, amount);
    }

    /**
     * @notice Withdraws the local balance
     * @param token The token
     * @param amount Amount to withdraw
     */
    function withdraw(address token, uint256 amount) external {
        require(
            context.blockMetadata.chainId == 0,
            "QPP: cannot be called within a mining context"
        );
        uint256 bal = state.getRemoteBalances(CHAIN_ID, token, msg.sender);
        require(bal >= amount, "QPP: Not enough balance");
        state.setRemoteBalances(CHAIN_ID, token, msg.sender, bal - amount);
        sendToken(token, msg.sender, amount);
        emit LocalTransfer(token, msg.sender, amount);
    }

    /**
     * @inheritdoc IQuantumPortalPoc
     */
    function msgSender()
        external
        view
        override
        returns (
            uint256 sourceNetwork,
            address sourceMsgSender,
            address sourceBeneficiary
        )
    {
        sourceNetwork = context.blockMetadata.chainId;
        sourceMsgSender = context.transaction.sourceMsgSender;
        sourceBeneficiary = context.transaction.sourceBeneficiary;
    }
}

contract QuantumPortalPocImpl is QuantumPortalPoc {
    constructor() PortalLedger(0) {}
}
