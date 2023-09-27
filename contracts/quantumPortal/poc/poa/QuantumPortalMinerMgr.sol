// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IQuantumPortalMinerMgr.sol";
import "./IQuantumPortalStake.sol";
import "./IDelegator.sol";
import "foundry-contracts/contracts/common/IFerrumDeployer.sol";
import "foundry-contracts/contracts/signature/MultiSigLib.sol";
import "./QuantumPortalWorkPoolClient.sol";
import "./QuantumPortalWorkPoolServer.sol";
import "./QuantumPortalMinerMembership.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "hardhat/console.sol";

/**
 @notice Miner manager provides functionality for QP miners; registration, staking,
         and allows the ledger manager to evaluate if the miner signature is valid,
         get miner's stake value, and also if the miner is allowed to mine the block.

         Anybody can become a miner with staking. But there are rules of minimum stake
         and lock amount.
 */
contract QuantumPortalMinerMgr is
    IQuantumPortalMinerMgr,
    EIP712,
    QuantumPortalWorkPoolServer,
    QuantumPortalWorkPoolClient,
    QuantumPortalMinerMembership
{
    struct SlashHistory {
        address delegatedMiner;
        address miner;
        bytes32 blockHash;
        address beneficiary;
    }

    uint32 constant WEEK = 3600 * 24 * 7;
    string public constant NAME = "FERRUM_QUANTUM_PORTAL_MINER_MGR";
    string public constant VERSION = "000.010";
    address public override miningStake;
    mapping(bytes32 => SlashHistory) slashes;

    event SlashRequested(SlashHistory data);

    constructor() EIP712(NAME, VERSION) {
        bytes memory _data = IFerrumDeployer(msg.sender).initData();
        (miningStake) = abi.decode(_data, (address));
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
    ) external view override returns (ValidationResult res, address signer) {
        // Validate miner signature
        // Get its stake
        // Validate miner has stake
        // TODO: Lmit who can call this function and then
        // add the value to miners validation history.
        // such that a miner has not limit-per-transaction
        // but limit per other things.
        signer = verifySignature(msgHash, salt, expiry, multiSig);
        require(signer != address(0), "QPMM: invalid signature");
        console.log("Signer is ?", signer);
        uint256 stake = IQuantumPortalStake(miningStake).delegatedStakeOf(
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
     * @param worker The miner address
     * @param fee The fee in FRM for the multi-chain transaction
     */
    function withdraw(uint256 remoteChain, address worker, uint fee) external {
        QuantumPortalWorkPoolClient.withdraw(
            IQuantumPortalWorkPoolServer.withdrawFixedRemote.selector,
            remoteChain,
            worker,
            fee
        );
    }

    bytes32 public constant MINER_SIGNATURE =
        keccak256("MinerSignature(bytes32 msgHash,uint64 expiry,bytes32 salt)");

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
        console.log("EXPIRY IS", expiry);
        console.log("MSG HASH");
        console.logBytes32(msgHash);
        require(block.timestamp < expiry, "CR: signature timed out");
        require(expiry < block.timestamp + WEEK, "CR: expiry too far");
        require(salt != 0, "MSC: salt required");
        address _signer = _extractMinerAddress(msgHash, salt, expiry, multiSig);
        require(_signer != address(0), "QPMM: wrong number of signatures");
        return _signer;
    }

    /**
     * @inheritdoc IQuantumPortalMinerMgr
     */
    function slashMinerForFraud(
        address delegatedMiner,
        bytes32 blockHash,
        address beneficiary
    ) external override onlyMgr {
        // TODO: For this version, we just record the slash, then the validator quorum will do the slash manually.
        // This is expexted to be a rare enough event.
        // Unregister the miner
        address miner = IDelegator(miningStake)
            .getReverseDelegation(delegatedMiner)
            .delegatee;
        SlashHistory memory data = SlashHistory({
            delegatedMiner: delegatedMiner,
            miner: miner,
            blockHash: blockHash,
            beneficiary: beneficiary
        });
        slashes[blockHash] = data;
        if (minerIdxsPlusOne[miner] != 0) {
            _unregisterMiner(delegatedMiner);
        }
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
        console.log("METHOD HASH");
        console.logBytes32(message);
        bytes32 digest = _hashTypedDataV4(message);
        console.log("DIGEST IS");
        console.logBytes32(digest);
        console.log("CHAIN_ID", block.chainid);
        console.log("ME", address(this));
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
}
