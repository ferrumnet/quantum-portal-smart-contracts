// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IQuantumPortalPoc.sol";
import "./IQuantumPortalLedgerMgr.sol";
import "./poa/IQuantumPortalStake.sol";
import "../../staking/interfaces/IStakeV2.sol";
import "../../uniswap/IWETH.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "foundry-contracts/contracts/common/IFerrumDeployer.sol";
import "foundry-contracts/contracts/common/WithAdmin.sol";
import "foundry-contracts/contracts/common/SafeAmount.sol";

/**
 * @notice Quantum portal gateway. This is the entry point allowing
 *     upate of QP contract logics. Always use this contract to interact
 *     with QP
 */
contract QuantumPortalGateway is WithAdmin, IQuantumPortalPoc {
    string public constant VERSION = "000.010";
    IQuantumPortalPoc public quantumPortalPoc;
    IQuantumPortalLedgerMgr public quantumPortalLedgerMgr;
    IQuantumPortalStake public quantumPortalStake;
    address public immutable WFRM;

    constructor() {
        bytes memory _data = IFerrumDeployer(msg.sender).initData();
        (WFRM) = abi.decode(_data, (address));
    }

    /**
     * @notice The authority manager contract
     */
    function quantumPortalAuthorityMgr() external view returns (address) {
        return
            IQuantumPortalLedgerMgrDependencies(address(quantumPortalLedgerMgr))
                .authorityMgr();
    }

    /**
     * @notice The miner manager contract
     */
    function quantumPortalMinerMgr() external view returns (address) {
        return
            IQuantumPortalLedgerMgrDependencies(address(quantumPortalLedgerMgr))
                .minerMgr();
    }

    /**
     * @notice Restricted: Upgrade the contract
     * @param poc The POC contract
     * @param ledgerMgr The ledger manager
     * @param qpStake The stake
     */
    function upgrade(
        address poc,
        address ledgerMgr,
        address qpStake
    ) external onlyAdmin {
        quantumPortalPoc = IQuantumPortalPoc(poc);
        quantumPortalLedgerMgr = IQuantumPortalLedgerMgr(ledgerMgr);
        quantumPortalStake = IQuantumPortalStake(qpStake);
    }

    /**
     * @notice The state contract
     */
    function state() external returns (address) {
        return address(quantumPortalLedgerMgr.state());
    }

    /**
     * @notice Stake for miner.
     * @param to The address to stake for.
     * @param amount The amount to stake. 0 if staking on the FRM chain.
     */
    function stake(address to, uint256 amount) external payable {
        _stake(to, amount);
    }

    /**
     * @notice Proxy methods for IQuantumPortalPoc
     */
    function feeTarget() external view override returns (address) {
        return quantumPortalPoc.feeTarget();
    }

    /**
     * @notice The fee token
     */
    function feeToken() external view override returns (address) {
        return quantumPortalPoc.feeToken();
    }

    /**
     * @notice Proxy to QP Ledger run method
     * @param remoteChain The remote chain ID
     * @param remoteContract The remote contract address
     * @param beneficiary The benficiary
     * @param remoteMethodCall The remote method call
     */
    function run(
        uint64 remoteChain,
        address remoteContract,
        address beneficiary,
        bytes memory remoteMethodCall
    ) external override {
        quantumPortalPoc.run(
            remoteChain,
            remoteContract,
            beneficiary,
            remoteMethodCall
        );
    }

    /**
     * @notice Proxy to QP ledger runWithValue method
     * @param remoteChain The remote chain ID
     * @param remoteContract The remote contract
     * @param beneficiary The beneficiary
     * @param token The token address
     * @param method The remote method call
     */
    function runWithValue(
        uint64 remoteChain,
        address remoteContract,
        address beneficiary,
        address token,
        bytes memory method
    ) external override {
        quantumPortalPoc.runWithValue(
            remoteChain,
            remoteContract,
            beneficiary,
            token,
            method
        );
    }

    /**
     * @notice Proxy to QP ledger runWithdraw method
     * @param remoteChainId The remote chain ID
     * @param remoteAddress The remote address
     * @param token The token
     * @param amount The amount
     */
    function runWithdraw(
        uint64 remoteChainId,
        address remoteAddress,
        address token,
        uint256 amount
    ) external override {
        quantumPortalPoc.runWithdraw(
            remoteChainId,
            remoteAddress,
            token,
            amount
        );
    }

    /**
     * @notice Proxy for QP msgSender
     * @return sourceNetwork The source network ID
     * @return sourceMsgSender The source message sender
     * @return sourceBeneficiary The benficiary
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
        return quantumPortalPoc.msgSender();
    }

    /**
     * @notice Proxy for QP txContext
     */
    function txContext()
        external
        view
        override
        returns (QuantumPortalLib.Context memory)
    {
        return quantumPortalPoc.txContext();
    }

    /**
     * @notice Proxy for QP remoteTransfer
     * @param chainId The remote chain ID
     * @param token The token address
     * @param to The to address
     * @param amount The amount
     */
    function remoteTransfer(
        uint256 chainId,
        address token,
        address to,
        uint256 amount
    ) external override {
        return quantumPortalPoc.remoteTransfer(chainId, token, to, amount);
    }

    /**
     * @notice Stake for the miner
     * @param to The staker
     * @param amount The stake amount
     */
    function _stake(address to, uint256 amount) private {
        require(to != address(0), "'to' is required");
        address baseToken = quantumPortalStake.STAKE_ID(); // Base token is the same as ID
        if (baseToken == WFRM) {
            uint256 frmAmount = msg.value;
            require(frmAmount != 0, "Value required");
            IWETH(WFRM).deposit{value: frmAmount}();
            require(
                IERC20(WFRM).balanceOf(address(this)) >= frmAmount,
                "Value not deposited"
            );
            IWETH(WFRM).transfer(address(quantumPortalStake), frmAmount);
            require(frmAmount != 0, "QPG: amount is required");
            IStakeV2(address(quantumPortalStake)).stake(to, baseToken);
        } else {
            amount = SafeAmount.safeTransferFrom(
                baseToken,
                msg.sender,
                address(quantumPortalStake),
                amount
            );
            require(amount != 0, "QPG: amount is required");
            IStakeV2(address(quantumPortalStake)).stake(to, baseToken);
        }
    }
}
