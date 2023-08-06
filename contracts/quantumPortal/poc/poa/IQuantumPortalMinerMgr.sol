// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IQuantumPortalMinerMgr {
    enum ValidationResult {
        None,
        Valid,
        NotEnoughStake
    }
    function miningStake() external view returns (address) ;
    function verifyMinerSignature(
        bytes32 msgHash,
        uint64 expiry,
        bytes32 salt,
        bytes memory signature,
        uint256 msgValue,
        uint256 minStakeAllowed
    ) external view returns (ValidationResult res, address signer);
    function slashMinerForFraud(address miner, bytes32 blockHash, address beneficiary) external;
}

