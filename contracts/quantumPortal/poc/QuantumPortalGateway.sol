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

    function quantumPortalAuthorityMgr() external view returns (address) {
        return IQuantumPortalLedgerMgrDependencies(quantumPortalLedgerMgr).authorityMgr();
    }

    function quantumPortalMinerMgr() external view returns (address) {
        return IQuantumPortalLedgerMgrDependencies(quantumPortalLedgerMgr).minerMgr();
    }

    /**
     * @notice Upgrade the contract
     * @param poc The POC contract
     * @param ledgerMgr The ledger manager
     * @param qpStake The stake
     */
    function upgrade(address poc, address ledgerMgr, address qpStake
    ) external onlyAdmin {
        quantumPortalPoc = IQuantumPortalPoc(poc);
        quantumPortalLedgerMgr = IQuantumPortalLedgerMgr(ledgerMgr);
        quantumPortalStake = IQuantumPortalStake(qpStake);
    }

    /**
     * @notice Stake for miner.
     * @param to The address to stake for.
     * @param amount The amount to stake. 0 if staking on the FRM chain.
     */
    function stake(address to, uint256 amount
    ) external payable {
        _stake(to, amount);
    }

    function _stake(address to, uint256 amount
    ) private {
        require(to != address(0), "'to' is required");
        address baseToken = quantumPortalStake.STAKE_ID(); // Base token is the same as ID
        if (baseToken == WFRM) {
            uint256 frmAmount = msg.value;
            require(frmAmount != 0, "Value required");
            IWETH(WFRM).deposit{ value: frmAmount }();
            require(IERC20(WFRM).balanceOf(address(this)) >= frmAmount, "Value not deposited");
            IWETH(WFRM).transfer(address(quantumPortalStake), frmAmount);
            require(frmAmount != 0, "QPG: amount is required");
            IStakeV2(address(quantumPortalStake)).stake(to, baseToken);
        } else {
            amount = SafeAmount.safeTransferFrom(baseToken, msg.sender, address(quantumPortalStake), amount);
            require(amount != 0, "QPG: amount is required");
            IStakeV2(address(quantumPortalStake)).stake(to, baseToken);
        }
    }

    /**
     * Proxy methods for IQuantumPortalPoc
     */
    function feeManager(
    ) external override view returns(address) {
        return quantumPortalPoc.feeManager();
    }

    function run(uint256 fee, uint64 remoteChain, address remoteContract, address beneficiary, bytes memory remoteMethodCall
    ) external override {
        quantumPortalPoc.run(fee, remoteChain, remoteContract, beneficiary, remoteMethodCall);
    }

    function runWithValue(
        uint256 fee, uint64 remoteChain, address remoteContract, address beneficiary, address token, bytes memory method
    ) external override {
        quantumPortalPoc.runWithValue(fee, remoteChain, remoteContract, beneficiary, token, method);
    }

    function runWithdraw(
        uint256 fee, uint64 remoteChainId, address remoteAddress, address token, uint256 amount
    ) external override {
        quantumPortalPoc.runWithdraw(fee, remoteChainId, remoteAddress, token, amount);
    }

    function msgSender(
    ) external override view returns (uint256 sourceNetwork, address sourceMsgSender, address sourceBeneficiary) {
        return quantumPortalPoc.msgSender();
    }

    function txContext(
    ) external override view returns (QuantumPortalLib.Context memory) {
        return quantumPortalPoc.txContext();
    }

    function remoteTransfer(uint256 chainId, address token, address to, uint256 amount
    ) external override {
        return quantumPortalPoc.remoteTransfer(chainId, token, to, amount);
    }
}