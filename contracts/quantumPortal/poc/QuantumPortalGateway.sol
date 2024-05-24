// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IQuantumPortalPoc.sol";
import "./IQuantumPortalLedgerMgr.sol";
import "./poa/stake/IQuantumPortalStakeWithDelegate.sol";
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
contract QuantumPortalGateway is WithAdmin {
    string public constant VERSION = "000.010";
    IQuantumPortalPoc public quantumPortalPoc;
    IQuantumPortalLedgerMgr public quantumPortalLedgerMgr;
    IQuantumPortalStakeWithDelegate public quantumPortalStake;
    address public immutable WFRM;

    constructor() Ownable(msg.sender) {
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
        quantumPortalStake = IQuantumPortalStakeWithDelegate(qpStake);
    }

    /**
     * @notice The state contract
     */
    function state() external returns (address) {
        return address(quantumPortalLedgerMgr.state());
    }

    /**
     * @notice Stake for miner.
     * @param to The staker address
     * @param delegate The miner/validator to delegate the stake for.
     * @param allocation The signed allocation
     * @param salt The signature salt
     * @param expiry The signature expiry
     * @param signature The signature
     */
    function stakeToDelegateWithAllocation(
        address to,
        address delegate,
        uint256 allocation,
        bytes32 salt,
        uint64 expiry,
        bytes memory signature
        ) external payable {
        quantumPortalStake.setDelegation(delegate, msg.sender);
        address baseToken = quantumPortalStake.STAKE_ID(); // Base token is the same as ID
        handleFRM(to, allocation, baseToken);
        quantumPortalStake.stakeToDelegateWithAllocation(
            to, delegate, allocation, salt, expiry, signature
        );
    }

    /**
     * @notice Stake for miner.
     * @param amount The amount to stake. 0 if staking on the FRM chain.
     * @param delegate The miner/validator to delegate the stake for.
     */
    function stakeToDelegate(uint256 amount, address delegate) external payable {
        quantumPortalStake.setDelegation(delegate, msg.sender);
        _stake(msg.sender, amount);
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
    function feeTarget() external view returns (address) {
        return quantumPortalPoc.feeTarget();
    }

    /**
     * @notice The fee token
     */
    function feeToken() external view returns (address) {
        return quantumPortalPoc.feeToken();
    }

    /**
     * @notice Stake for the miner
     * @param to The staker
     * @param amount The stake amount
     */
    function _stake(address to, uint256 amount) private {
        address baseToken = quantumPortalStake.STAKE_ID(); // Base token is the same as ID
        handleFRM(to, amount, baseToken);
        IStakeV2(address(quantumPortalStake)).stake(to, baseToken);
    }

    function handleFRM(address to, uint256 amount, address baseToken) private {
        require(to != address(0), "'to' is required");
        if (baseToken == WFRM) {
            uint256 frmAmount = msg.value;
            require(frmAmount != 0, "Value required");
            IWETH(WFRM).deposit{value: frmAmount}();
            require(
                IERC20(WFRM).balanceOf(address(this)) >= frmAmount,
                "Value not deposited"
            );
            IWETH(WFRM).transfer(address(quantumPortalStake), frmAmount);
        } else {
            amount = SafeAmount.safeTransferFrom(
                baseToken,
                msg.sender,
                address(quantumPortalStake),
                amount
            );
            require(amount != 0, "QPG: amount is required");
        }
    }
}
