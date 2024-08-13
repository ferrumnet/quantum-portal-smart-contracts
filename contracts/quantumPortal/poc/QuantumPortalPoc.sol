// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "foundry-contracts/contracts/contracts/common/IVersioned.sol";
import "./IQuantumPortalPoc.sol";
import "./IQuantumPortalNativeFeeRepo.sol";
import "./utils/IQpSelfManagedToken.sol";
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
    string public constant override VERSION = "000.001";
    address public override feeTarget; // FeeTarget is MinerMgr contract.
    address public override feeToken;
    address public nativeFeeRepo;

    event LocalTransfer(address token, address to, uint256 amount);

    /**
     * @notice Updates the fee target, in case it is changed
     */
    function updateFeeTarget() external {
        feeTarget = IQuantumPortalLedgerMgrDependencies(mgr).minerMgr();
    }

    /**
     * @notice Ristricted: Sets the fee token
     * @param _feeToken The fee token
     */
    function setFeeToken(address _feeToken) external onlyAdmin {
        feeToken = _feeToken;
    }

    function setNativeFeeRepo(address _nativeFeeRepo) external onlyAdmin {
        nativeFeeRepo = _nativeFeeRepo;
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
    function runFromTokenNativeFee(
        uint64 remoteChainId,
        address remoteContract,
        address beneficiary,
        bytes memory remoteMethodCall,
        uint256 amount
    ) external payable override {
        require(remoteContract != address(0) || beneficiary != address(0), "remoteContract or beneficiary is required");
        IQuantumPortalNativeFeeRepo(nativeFeeRepo).swapFee{value: msg.value}();
        IQuantumPortalLedgerMgr(mgr).registerTransaction(
            remoteChainId,
            remoteContract,
            msg.sender,
            beneficiary,
            msg.sender, // msg.sender will be the token itself
            amount,
            remoteMethodCall
        );
    }

    /**
     * @inheritdoc IQuantumPortalPoc
     */
    function runFromToken(
        uint64 remoteChainId,
        address remoteContract,
        address beneficiary,
        bytes memory remoteMethodCall,
        uint256 amount
    ) external override {
        require(remoteContract != address(0) || beneficiary != address(0), "remoteContract or beneficiary is required");
        IQuantumPortalLedgerMgr(mgr).registerTransaction(
            remoteChainId,
            remoteContract,
            msg.sender,
            beneficiary,
            msg.sender, // msg.sender will be the token itself
            amount,
            remoteMethodCall
        );
    }

    /**
     * @inheritdoc IQuantumPortalPoc
     */
    function runNativeFee(
        uint64 remoteChainId,
        address remoteContract,
        address beneficiary,
        bytes memory remoteMethodCall
    ) external payable override {
        require(remoteContract != address(0) || beneficiary != address(0), "remoteContract or beneficiary is required");
        require(remoteMethodCall.length != 0, "remoteMethodCall is required");
        IQuantumPortalNativeFeeRepo(nativeFeeRepo).swapFee{value: msg.value}();
        // require(remoteChainId != CHAIN_ID, "Remote cannot be self");
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
    function run(
        uint64 remoteChainId,
        address remoteContract,
        address beneficiary,
        bytes memory remoteMethodCall
    ) external override {
        require(remoteContract != address(0) || beneficiary != address(0), "remoteContract or beneficiary is required");
        require(remoteMethodCall.length != 0, "remoteMethodCall is required");
        // require(remoteChainId != CHAIN_ID, "Remote cannot be self");
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
    function runWithValueNativeFee(
        uint64 remoteChainId,
        address remoteContract,
        address beneficiary,
        address token,
        bytes memory method
    ) external payable override {
        require(remoteContract != address(0) || beneficiary != address(0), "remoteContract or beneficiary is required");
        // require(remoteChainId != CHAIN_ID, "Remote cannot be self");
        IQuantumPortalNativeFeeRepo(nativeFeeRepo).swapFee{value: msg.value}();
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
    function runWithValue(
        uint64 remoteChainId,
        address remoteContract,
        address beneficiary,
        address token,
        bytes memory method
    ) external override {
        require(remoteContract != address(0) || beneficiary != address(0), "remoteContract or beneficiary is required");
        // require(remoteChainId != CHAIN_ID, "Remote cannot be self");
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
     * @inheritdoc IQuantumPortalPoc
     */
    function localTransfer(
        address token,
        address to,
        uint256 amount
    ) external override {
        console.log("LOCAL TX");
        require(
            msg.sender == context.transaction.remoteContract,
            "QPP: can only be called within a mining context"
        );
        console.log("LOCAL TX2");
        if (
            token == context.transaction.token
        ) {
            context.uncommitedBalance -= amount;
        } else {
            console.log("UPDATING BAL", amount, msg.sender);
            // TODO: What if the tx failed? Make sure this will be reverted
            state.setRemoteBalances(
                CHAIN_ID,
                token,
                msg.sender,
                state.getRemoteBalances(CHAIN_ID, token, msg.sender) - amount
            );
        }
        // Instead of updating the remoteBalcne for `to`, we just send them tokens
        emit RemoteTransfer(CHAIN_ID, token, msg.sender, to, amount);
        emit LocalTransfer(token, to, amount);
        console.log('SENDING TOKENS');
        if (isSelfManagedToken(token)) {
            // Virtual balances are managed by token contract. There is no real balance so we just 
            // use the transfer method without inventory control.
            IERC20(token).transfer(to, amount);
        } else {
            sendToken(token, to, amount);
        }
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

    function isSelfManagedToken(address token) private view returns (bool) {
        (bool result, ) = token.staticcall(abi.encodeWithSelector(IQpSelfManagedToken.isQpSelfManagedToken.selector));
        return result;
    }
}

contract QuantumPortalPocImpl is QuantumPortalPoc {
    constructor() PortalLedger(0) Ownable(msg.sender) {}
}
