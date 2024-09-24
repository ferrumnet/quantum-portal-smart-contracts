// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UUPSUpgradeable, Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IVersioned} from "foundry-contracts/contracts/contracts/common/IVersioned.sol";
import {IQuantumPortalPoc} from "./IQuantumPortalPoc.sol";
import {IQuantumPortalNativeFeeRepo} from "./IQuantumPortalNativeFeeRepo.sol";
import {IQpSelfManagedToken} from "./utils/IQpSelfManagedToken.sol";
import {IQuantumPortalLedgerMgrDependencies} from "./IQuantumPortalLedgerMgr.sol";
import {IQuantumPortalLedgerMgr} from "./IQuantumPortalLedgerMgr.sol";
import {TokenReceivableUpgradeable} from "./poa/stake/library/TokenReceivableUpgradeable.sol";
import {PortalLedgerUpgradeable} from "./PortalLedgerUpgradeable.sol";
import {QuantumPortalLib} from "./QuantumPortalLib.sol";


/**
 * @notice The quantum portal main contract for multi-chain dApps
 */
abstract contract QuantumPortalPocUpgradeable is
    Initializable, 
    UUPSUpgradeable,
    TokenReceivableUpgradeable,
    PortalLedgerUpgradeable,
    IQuantumPortalPoc,
    IVersioned
{
    string public constant override VERSION = "000.001";

    /// @custom:storage-location erc7201:ferrum.storage.quantumportalpoc.001
    struct QuantumPortalPocStorageV001 {
        address feeTarget; // FeeTarget is MinerMgr contract.
        address feeToken;
        address nativeFeeRepo;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.quantumportalpoc.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant QuantumPortalPocStorageV001Location = 0x3efde86585235858ed707e4bfec31c6043b9cbe60e54ce19376b9c89b48f7600;

    function initialize(address initialOwner, address initialAdmin) public initializer {
        __PortalLedger_init(initialOwner, initialAdmin);
        __TokenReceivable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    function _getQuantumPortalPocStorageV001() internal pure returns (QuantumPortalPocStorageV001 storage $) {
        assembly {
            $.slot := QuantumPortalPocStorageV001Location
        }
    }

    event LocalTransfer(address token, address to, uint256 amount);

    function feeTarget() public view returns (address) {
        return _getQuantumPortalPocStorageV001().feeTarget;
    }

    function feeToken() public view returns (address) {
        return _getQuantumPortalPocStorageV001().feeToken;
    }

    function nativeFeeRepo() public view returns (address) {
        return _getQuantumPortalPocStorageV001().nativeFeeRepo;
    }

    /**
     * @notice Updates the fee target, in case it is changed
     */
    function updateFeeTarget() external {
        QuantumPortalPocStorageV001 storage $ = _getQuantumPortalPocStorageV001();
        $.feeTarget = IQuantumPortalLedgerMgrDependencies(mgr()).minerMgr();
    }

    /**
     * @notice Ristricted: Sets the fee token
     * @param _feeToken The fee token
     */
    function setFeeToken(address _feeToken) external onlyAdmin {
        QuantumPortalPocStorageV001 storage $ = _getQuantumPortalPocStorageV001();
        $.feeToken = _feeToken;
    }

    function setNativeFeeRepo(address _nativeFeeRepo) external onlyAdmin {
        QuantumPortalPocStorageV001 storage $ = _getQuantumPortalPocStorageV001();
        $.nativeFeeRepo = _nativeFeeRepo;
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
        return context();
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
        IQuantumPortalNativeFeeRepo(nativeFeeRepo()).swapFee{value: msg.value}();
        IQuantumPortalLedgerMgr(mgr()).registerTransaction(
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
        IQuantumPortalLedgerMgr(mgr()).registerTransaction(
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
        IQuantumPortalNativeFeeRepo(nativeFeeRepo()).swapFee{value: msg.value}();
        // require(remoteChainId != CHAIN_ID, "Remote cannot be self");
        IQuantumPortalLedgerMgr(mgr()).registerTransaction(
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
        IQuantumPortalLedgerMgr(mgr()).registerTransaction(
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
        IQuantumPortalNativeFeeRepo(nativeFeeRepo()).swapFee{value: msg.value}();
        IQuantumPortalLedgerMgr(mgr()).registerTransaction(
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
        IQuantumPortalLedgerMgr(mgr()).registerTransaction(
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
        _setRemoteBalances(
            remoteChainId,
            token,
            msg.sender,
            getRemoteBalances(remoteChainId, token, msg.sender) - amount
        );
        IQuantumPortalLedgerMgr(mgr()).registerTransaction(
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
            msg.sender == context().transaction.remoteContract,
            "QPP: can only be called within a mining context"
        );
        if (
            chainId == context().blockMetadata.chainId &&
            token == context().transaction.token
        ) {
            context().uncommitedBalance -= amount;
        } else {
            _setRemoteBalances(
                chainId,
                token,
                msg.sender,
                getRemoteBalances(chainId, token, msg.sender) - amount
            );
        }
        _setRemoteBalances(
            chainId,
            token,
            to,
            getRemoteBalances(chainId, token, to) + amount
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
        require(
            msg.sender == context().transaction.remoteContract,
            "QPP: can only be called within a mining context"
        );
        if (
            token == context().transaction.token
        ) {
            context().uncommitedBalance -= amount;
        } else {
            // TODO: What if the tx failed? Make sure this will be reverted
            _setRemoteBalances(
                CHAIN_ID,
                token,
                msg.sender,
                getRemoteBalances(CHAIN_ID, token, msg.sender) - amount
            );
        }
        // Instead of updating the remoteBalcne for `to`, we just send them tokens
        emit RemoteTransfer(CHAIN_ID, token, msg.sender, to, amount);
        emit LocalTransfer(token, to, amount);
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
            context().blockMetadata.chainId == 0,
            "QPP: cannot be called within a mining context"
        );
        uint256 bal = getRemoteBalances(CHAIN_ID, token, msg.sender);
        require(bal >= amount, "QPP: Not enough balance");
        _setRemoteBalances(CHAIN_ID, token, msg.sender, bal - amount);
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
        sourceNetwork = context().blockMetadata.chainId;
        sourceMsgSender = context().transaction.sourceMsgSender;
        sourceBeneficiary = context().transaction.sourceBeneficiary;
    }

    function isSelfManagedToken(address token) private view returns (bool) {
        (bool result, ) = token.staticcall(abi.encodeWithSelector(IQpSelfManagedToken.isQpSelfManagedToken.selector));
        return result;
    }
}

contract QuantumPortalPocImplUpgradeable is QuantumPortalPocUpgradeable {
    constructor() PortalLedgerUpgradeable(0) {}
}
