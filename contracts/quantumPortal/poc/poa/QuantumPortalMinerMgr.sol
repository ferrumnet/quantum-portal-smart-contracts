// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../staking/interfaces/IStakeInfo.sol";
import "foundary-contracts/contracts/signature/MultiSigCheckable.sol";

interface IQuantumPortalMinerMgr {
    enum ValidationResult {
        None,
        Valid,
        NotEnoughStake
    }
    function validateMinerSignature(
        bytes32 msgHash,
        uint256 expiry,
        bytes32 salt,
        bytes memory signature,
        uint256 msgValue,
        uint256 minStakeAllowed
    ) external returns (ValidationResult res);
}

/**
 @notice Miner manager provides functionality for QP miners; registration, staking,
         and allows the ledger manager to evaluate if the miner signature is valid,
         get miner's stake value, and also if the miner is allowed to mine the block.

         Anybody can become a miner with staking. But there are rules of minimum stake
         and lock amount.
 */
contract QuantumPortalMinerMgr is IQuantumPortalMinerMgr, MultiSigCheckable {
    string public constant NAME = "FERRUM_QUANTUM_PORTAL_MINER_MGR";
    string public constant VERSION = "000.010";
    address constant QP_STAKE_ID = address(1);
    address miningStake;

    constructor() EIP712(NAME, VERSION) {}

    function validateMinerSignature(
        bytes32 msgHash,
        uint256 expiry,
        bytes32 salt,
        bytes memory signature,
        uint256 msgValue,
        uint256 minStakeAllowed
    ) external override returns (ValidationResult res) {
        // Validate miner signature
        // Get its stake
        // Validate miner has stake
        // TODO: Lmit who can call this function and then
        // add the value to miners validation history.
        // such that a miner has not limit-per-transaction
        // but limit per other things.
        (bool result, address[] memory signers) = tryVerifyDigestWithAddress(msgHash, 0, signature);
        require(result, "QPMM: invalid signature");
        require(signers.length != 0, "QPMM: not a valid signature");
        uint256 totalValue = 0;
        for(uint i=0; i<signers.length; i++) {
            uint256 stake = IStakeInfo(miningStake).stakeOf(QP_STAKE_ID, signers[i]);
            require(stake>=minStakeAllowed, "QPMM: One miner has less than allowed stake");
            totalValue += stake;
        }
        require(totalValue != 0, "QPMM: No valid miner");
        return totalValue >= minStakeAllowed ? ValidationResult.Valid : ValidationResult.NotEnoughStake;
    }
}