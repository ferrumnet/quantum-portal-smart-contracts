// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Initializable, UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MultiSigLib} from "foundry-contracts/contracts/contracts/signature/MultiSigLib.sol";
import {IQuantumPortalMinerMgr} from "./IQuantumPortalMinerMgr.sol";
import {IQuantumPortalStakeWithDelegate} from "./stake/IQuantumPortalStakeWithDelegate.sol";
import {IDelegator} from "./IDelegator.sol";
import {QuantumPortalWorkPoolClientUpgradeable, IQuantumPortalWorkPoolClient} from "./QuantumPortalWorkPoolClientUpgradeable.sol";
import {QuantumPortalWorkPoolServerUpgradeable, IQuantumPortalWorkPoolServer} from "./QuantumPortalWorkPoolServerUpgradeable.sol";
import {QuantumPortalMinerMembershipUpgradeable, IQuantumPortalMinerMembership} from "./QuantumPortalMinerMembershipUpgradeable.sol";


/**
 @notice Miner manager provides functionality for QP miners; registration, staking,
         and allows the ledger manager to evaluate if the miner signature is valid,
         get miner's stake value, and also if the miner is allowed to mine the block.

         Anybody can become a miner with staking. But there are rules of minimum stake
         and lock amount.
 */
contract QuantumPortalMinerMgrUpgradeable is
    IQuantumPortalMinerMgr,
    Initializable,
    UUPSUpgradeable,
    EIP712Upgradeable,
    QuantumPortalWorkPoolServerUpgradeable,
    QuantumPortalWorkPoolClientUpgradeable,
    QuantumPortalMinerMembershipUpgradeable
{
    uint32 constant WEEK = 7 days;
    string public constant NAME = "FERRUM_QUANTUM_PORTAL_MINER_MGR";
    string public constant VERSION = "000.010";
    bytes32 public constant MINER_SIGNATURE =
        keccak256("MinerSignature(bytes32 msgHash,uint64 expiry,bytes32 salt)");

    /// @custom:storage-location erc7201:ferrum.storage.quantumportalminermgr.001
    struct QuantumPortalMinerMgrStorageV001 {
        address miningStake;
        mapping(bytes32 => SlashHistory) slashes;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.quantumportalminermgr.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant QuantumPortalMinerMgrStorageV001Location = 0x7bb1cda3307fd7c4d258294380d895ba9ce218c73ff0de939dec0815554aac00;

    struct SlashHistory {
        address delegatedMiner;
        address miner;
        bytes32 blockHash;
        address beneficiary;
    }

    event MinerSlashed (
        address delegatedMiner,
        address indexed miner,
        bytes32 blockHash,
        address beneficiary
    );

    event SlashRequested(SlashHistory data);

    function initialize(
        address _miningStake,
        address _portal,
        address _mgr,
        address _initialOwner
    ) public initializer {
        QuantumPortalMinerMgrStorageV001 storage $ = _getQuantumPortalMinerMgrStorageV001();
        $.miningStake = _miningStake;
        __EIP712_init(NAME, VERSION);
        __QuantimPortalWorkPoolServer_init(_mgr, _portal, _initialOwner, _initialOwner);
        __UUPSUpgradeable_init();
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    function miningStake() public view returns (address) {
        return _getQuantumPortalMinerMgrStorageV001().miningStake;
    }

    /**
     * @inheritdoc IQuantumPortalMinerMembership
     */
    function selectMiner(
        address requestedMiner,
        bytes32 blockHash,
        uint256 blockTimestamp
    ) external override onlyMgr returns (bool) {
        return _selectMiner(requestedMiner, blockHash, blockTimestamp);
    }

    /**
     * @inheritdoc IQuantumPortalMinerMembership
     */
    function registerMiner(address miner) external override onlyMgr {
        _registerMiner(miner);
    }

    /**
     * @inheritdoc IQuantumPortalMinerMembership
     */
    function unregisterMiner(address miner) external override onlyMgr {
        _unregisterMiner(miner);
    }

    /**
     * @inheritdoc IQuantumPortalMinerMembership
     */
    function unregister() external override {
        _unregisterMiner(msg.sender);
    }

    /**
     * @inheritdoc IQuantumPortalMinerMgr
     */
    function extractMinerAddress(
        bytes32 msgHash,
        bytes32 salt,
        uint64 expiry,
        bytes memory multiSig
    ) external view override returns (address) {
        return _extractMinerAddress(msgHash, salt, expiry, multiSig);
    }

    /**
     * @inheritdoc IQuantumPortalMinerMgr
     */
    function verifyMinerSignature(
        bytes32 msgHash,
        bytes32 salt,
        uint64 expiry,
        bytes memory multiSig,
        uint256 /*msgValue*/,
        uint256 minStakeAllowed
    ) external view override returns (ValidationResult res, address signer, uint256 stake) {
        // Validate miner signature
        // Get its stake
        // Validate miner has stake
        signer = verifySignature(msgHash, salt, expiry, multiSig);
        require(signer != address(0), "QPMM: invalid signature");
        stake = IQuantumPortalStakeWithDelegate(miningStake()).stakeOfDelegate(
            signer
        );
        require(stake != 0, "QPMM: Not a valid miner");
        res = stake >= minStakeAllowed
            ? ValidationResult.Valid
            : ValidationResult.NotEnoughStake;
    }

    /**
     * @notice Withdraw miner rewards on the remote chain
     * @param remoteChain The remote chain ID
     * @param to The address to receive funds
     * @param worker The miner address
     * @param fee The fee in FRM for the multi-chain transaction
     */
    function withdraw(uint256 remoteChain, address to, address worker, uint fee) external {
        QuantumPortalWorkPoolClientUpgradeable.withdraw(
            IQuantumPortalWorkPoolServer.withdrawFixedRemote.selector,
            remoteChain,
            to,
            worker,
            fee
        );
    }

    /**
     * @inheritdoc IQuantumPortalMinerMgr
     */
    function slashMinerForFraud(
        address delegatedMiner,
        bytes32 blockHash,
        address beneficiary
    ) external override onlyMgr {
        // Note: For this version, we just record the slash, then the validator quorum will do the slash manually.
        // This is expected to be a rare enough event.
        // Unregister the miner
        QuantumPortalMinerMgrStorageV001 storage $ = _getQuantumPortalMinerMgrStorageV001();
        address miner = IDelegator(miningStake())
            .getReverseDelegation(delegatedMiner)
            .delegatee;
        SlashHistory memory data = SlashHistory({
            delegatedMiner: delegatedMiner,
            miner: miner,
            blockHash: blockHash,
            beneficiary: beneficiary
        });
        $.slashes[blockHash] = data;
        if (minerIdxsPlusOne(miner) != 0) {
            _unregisterMiner(delegatedMiner);
        }
        emit MinerSlashed (delegatedMiner, miner, blockHash, beneficiary);
    }

    /**
     * @notice Vrify miner signature
     * @param msgHash The message hash
     * @param salt The salt
     * @param expiry The expiry
     * @param multiSig The multi signature
     */
    function verifySignature(
        bytes32 msgHash,
        bytes32 salt,
        uint64 expiry,
        bytes memory multiSig
    ) internal view returns (address) {
        require(block.timestamp < expiry, "CR: signature timed out");
        require(expiry < block.timestamp + WEEK, "CR: expiry too far");
        require(salt != 0, "MSC: salt required");
        address _signer = _extractMinerAddress(msgHash, salt, expiry, multiSig);
        require(_signer != address(0), "QPMM: wrong number of signatures");
        return _signer;
    }

    /**
     * @notice Extract miner address from the signature
     * @param msgHash The block hash
     * @param salt The salt
     * @param expiry The expiry
     * @param multiSig The multi sig
     */
    function _extractMinerAddress(
        bytes32 msgHash,
        bytes32 salt,
        uint64 expiry,
        bytes memory multiSig
    ) internal view returns (address) {
        bytes32 message = keccak256(
            abi.encode(MINER_SIGNATURE, msgHash, expiry, salt)
        );
        bytes32 digest = _hashTypedDataV4(message);
        MultiSigLib.Sig[] memory signatures = MultiSigLib.parseSig(multiSig);
        if (signatures.length != 1) {
            return address(0);
        }
        address _signer = ECDSA.recover(
            digest,
            signatures[0].v,
            signatures[0].r,
            signatures[0].s
        );
        return _signer;
    }

    function _getQuantumPortalMinerMgrStorageV001() internal pure returns (QuantumPortalMinerMgrStorageV001 storage $) {
        assembly {
            $.slot := QuantumPortalMinerMgrStorageV001Location
        }
    }
}
