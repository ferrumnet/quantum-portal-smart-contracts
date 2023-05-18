// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "foundry-contracts/contracts/common/IFerrumDeployer.sol";
import "foundry-contracts/contracts/signature/MultiSigLib.sol";
import "./IQuantumPortalMinerMgr.sol";
import "./IQuantumPortalStake.sol";
import "./QuantumPortalWorkPoolClient.sol";
import "./QuantumPortalWorkPoolServer.sol";
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
contract QuantumPortalMinerMgr is IQuantumPortalMinerMgr, EIP712, QuantumPortalWorkPoolServer, QuantumPortalWorkPoolClient {
    string public constant NAME = "FERRUM_QUANTUM_PORTAL_MINER_MGR";
    string public constant VERSION = "000.010";
    uint32 constant WEEK = 3600 * 24 * 7;
    address public miningStake;

    constructor() EIP712(NAME, VERSION) {
        bytes memory _data = IFerrumDeployer(msg.sender).initData();
        (miningStake) = abi.decode(_data, (address));
    }

    function verifyMinerSignature(
        bytes32 msgHash,
        uint64 expiry,
        bytes32 salt,
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
        signer = verifySignature(msgHash, expiry, salt, multiSig);
        require(signer != address(0), "QPMM: invalid signature");
        console.log("Signer is ?", signer);
        uint256 stake = IQuantumPortalStake(miningStake).delegatedStakeOf(signer);
        require(stake!=0, "QPMM: Not a valid miner");
        res = stake >= minStakeAllowed ? ValidationResult.Valid : ValidationResult.NotEnoughStake;
    }

    bytes32 constant MINER_SIGNATURE = keccak256("MinerSignature(bytes32 msgHash,uint64 expiry,bytes32 salt)");
    function verifySignature(
        bytes32 msgHash,
        uint64 expiry,
        bytes32 salt,
        bytes memory multiSig
    ) internal view returns (address) {
        console.log("EXPIRY IS", expiry);
        console.log("MSG HASH");
        console.logBytes32(msgHash);
        require(block.timestamp < expiry, "CR: signature timed out");
        require(expiry < block.timestamp + WEEK, "CR: expiry too far");
        require(salt != 0, "MSC: salt required");
        bytes32 message = keccak256(abi.encode(MINER_SIGNATURE, msgHash, expiry, salt));
        console.log("METHOD HASH");
        console.logBytes32(message);
        bytes32 digest = _hashTypedDataV4(message);
        console.log("DIGEST IS");
        console.logBytes32(digest);
        console.log("CHAIN_ID", block.chainid);
        console.log("ME", address(this));
        MultiSigLib.Sig[] memory signatures = MultiSigLib.parseSig(multiSig);
        require(signatures.length == 1, "QPMM: wrong number of signatures");
        address _signer = ECDSA.recover(
            digest,
            signatures[0].v,
            signatures[0].r,
            signatures[0].s
        );
        return _signer;
    }

    function withdraw(uint256 remoteChain, address worker, uint fee) external {
        withdraw(IQuantumPortalWorkPoolServer.withdrawFixedRemote.selector, remoteChain, worker, fee);
    }
}