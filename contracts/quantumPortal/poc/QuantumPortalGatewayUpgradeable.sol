// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UUPSUpgradeable, Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeAmount} from "foundry-contracts/contracts/contracts/common/SafeAmount.sol";
import {FerrumAdminUpgradeable} from "foundry-contracts/contracts/contracts-upgradeable/common/FerrumAdminUpgradeable.sol";
import {IQuantumPortalLedgerMgr, IQuantumPortalLedgerMgrDependencies} from "./IQuantumPortalLedgerMgr.sol";
import {IQuantumPortalStakeWithDelegate} from "./poa/stake/IQuantumPortalStakeWithDelegate.sol";
import {IQuantumPortalPoc} from "./IQuantumPortalPoc.sol";
import {IStakeV2} from "./poa/stake/interfaces/IStakeV2.sol";
import {IWETH} from "../../uniswap/IWETH.sol";
import {IUUPSUpgradeable} from "./utils/IUUPSUpgradeable.sol";


/**
 * @notice Quantum portal gateway. This is the entry point allowing
 *     upate of QP contract logics. Always use this contract to interact
 *     with QP
 */
contract QuantumPortalGatewayUpgradeable is Initializable, UUPSUpgradeable, FerrumAdminUpgradeable {
    string public constant NAME = "FERRUM_QUANTUM_PORTAL_GATEWAY";
    string public constant VERSION = "000.001";
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable WFRM;

    /// @custom:storage-location erc7201:ferrum.storage.quantumportalgateway.001
    struct QuantumPortalGatewayStorageV001 {
        IQuantumPortalPoc quantumPortalPoc;
        IQuantumPortalLedgerMgr quantumPortalLedgerMgr;
        IQuantumPortalStakeWithDelegate quantumPortalStake;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.quantumportalgateway.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant QuantumPortalGatewayStorageV001Location = 0x46c5798395a0011f331d8eec5650e2e6734295f226e6e625871a7aef21910b00;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _wfrm) {
        WFRM = _wfrm;
    }

    function initialize(uint256 _timelockPeriod,
        address initialOwner,
        address initialAdmin
    ) public initializer {
        __FerrumAdmin_init(
            _timelockPeriod,
            initialOwner,
            initialAdmin,
            NAME,
            VERSION
        );
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    function _getQuantumPortalGatewayStorageV001() internal pure returns (QuantumPortalGatewayStorageV001 storage $) {
        assembly {
            $.slot := QuantumPortalGatewayStorageV001Location
        }
    }

    function quantumPortalPoc() external view returns (address) {
        QuantumPortalGatewayStorageV001 storage $ = _getQuantumPortalGatewayStorageV001();
        return address($.quantumPortalPoc);
    }

    function quantumPortalLedgerMgr() external view returns (address) {
        QuantumPortalGatewayStorageV001 storage $ = _getQuantumPortalGatewayStorageV001();
        return address($.quantumPortalLedgerMgr);
    }

    function quantumPortalStake() external view returns (address) {
        QuantumPortalGatewayStorageV001 storage $ = _getQuantumPortalGatewayStorageV001();
        return address($.quantumPortalStake);
    }

    /**
     * @notice The authority manager contract
     */
    function quantumPortalAuthorityMgr() external view returns (address) {
        QuantumPortalGatewayStorageV001 storage $ = _getQuantumPortalGatewayStorageV001();
        return
            IQuantumPortalLedgerMgrDependencies(address($.quantumPortalLedgerMgr))
                .authorityMgr();
    }

    /**
     * @notice The miner manager contract
     */
    function quantumPortalMinerMgr() external view returns (address) {
        QuantumPortalGatewayStorageV001 storage $ = _getQuantumPortalGatewayStorageV001();
        return
            IQuantumPortalLedgerMgrDependencies(address($.quantumPortalLedgerMgr))
                .minerMgr();
    }

    /**
     * @notice Restricted: Update the addresses for poc (the ledger), ledger manager and stake
     * @param poc The POC contract
     * @param ledgerMgr The ledger manager
     * @param qpStake The stake
     */
    function updateQpAddresses(
        address poc,
        address ledgerMgr,
        address qpStake
    ) external onlyAdmin {
        QuantumPortalGatewayStorageV001 storage $ = _getQuantumPortalGatewayStorageV001();
        $.quantumPortalPoc = IQuantumPortalPoc(poc);
        $.quantumPortalLedgerMgr = IQuantumPortalLedgerMgr(ledgerMgr);
        $.quantumPortalStake = IQuantumPortalStakeWithDelegate(qpStake);
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
        QuantumPortalGatewayStorageV001 storage $ = _getQuantumPortalGatewayStorageV001();
        $.quantumPortalStake.setDelegation(delegate, msg.sender);
        address baseToken = $.quantumPortalStake.STAKE_ID(); // Base token is the same as ID
        handleFRM(to, allocation, baseToken);
        $.quantumPortalStake.stakeToDelegateWithAllocation(
            to, delegate, allocation, salt, expiry, signature
        );
    }

    /**
     * @notice Stake for miner.
     * @param amount The amount to stake. 0 if staking on the FRM chain.
     * @param delegate The miner/validator to delegate the stake for.
     */
    function stakeToDelegate(uint256 amount, address delegate) external payable {
        QuantumPortalGatewayStorageV001 storage $ = _getQuantumPortalGatewayStorageV001();
        $.quantumPortalStake.setDelegation(delegate, msg.sender);
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
        QuantumPortalGatewayStorageV001 storage $ = _getQuantumPortalGatewayStorageV001();
        return $.quantumPortalPoc.feeTarget();
    }

    /**
     * @notice The fee token
     */
    function feeToken() external view returns (address) {
        QuantumPortalGatewayStorageV001 storage $ = _getQuantumPortalGatewayStorageV001();
        return $.quantumPortalPoc.feeToken();
    }

    /**
     * @notice Stake for the miner
     * @param to The staker
     * @param amount The stake amount
     */
    function _stake(address to, uint256 amount) private {
        QuantumPortalGatewayStorageV001 storage $ = _getQuantumPortalGatewayStorageV001();
        address baseToken = $.quantumPortalStake.STAKE_ID(); // Base token is the same as ID
        handleFRM(to, amount, baseToken);
        IStakeV2(address($.quantumPortalStake)).stake(to, baseToken);
    }

    function handleFRM(address to, uint256 amount, address baseToken) private {
        QuantumPortalGatewayStorageV001 storage $ = _getQuantumPortalGatewayStorageV001();
        require(to != address(0), "'to' is required");
        if (baseToken == WFRM) {
            uint256 frmAmount = msg.value;
            require(frmAmount != 0, "Value required");
            IWETH(WFRM).deposit{value: frmAmount}();
            require(
                IERC20(WFRM).balanceOf(address(this)) >= frmAmount,
                "Value not deposited"
            );
            IWETH(WFRM).transfer(address($.quantumPortalStake), frmAmount);
        } else {
            amount = SafeAmount.safeTransferFrom(
                baseToken,
                msg.sender,
                address($.quantumPortalStake),
                amount
            );
            require(amount != 0, "QPG: amount is required");
        }
    }
}
