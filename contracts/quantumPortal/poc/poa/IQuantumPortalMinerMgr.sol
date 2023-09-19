// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IQuantumPortalMinerMgr {
    enum ValidationResult {
        None,
        Valid,
        NotEnoughStake
    }

    /**
     * @notice Returns the mining stake for the owner
     */
    function miningStake() external view returns (address);

    /**
     * @notice Extract the miner address from a block
     * @param msgHash The block hash
     * @param expiry signature expiry
     * @param salt The unique salt
     * @param multiSig The multisig
     * @return Miner address or zero
     */
    function extractMinerAddress(
        bytes32 msgHash,
        uint64 expiry,
        bytes32 salt,
        bytes memory multiSig
    ) external view returns (address);

    /**
     * @notice Verify if the signature is valid and return miner address
     * @param msgHash The block hash
     * @param expiry signature expiry
     * @param salt The unique salt
     * @param signature The multisig
     * @param msgValue The value included in the message
     * @param minStakeAllowed Allowed minimum stake
     * @return res Validation result as `ValidationResult`
     * @return signer The miner address
     */
    function verifyMinerSignature(
        bytes32 msgHash,
        uint64 expiry,
        bytes32 salt,
        bytes memory signature,
        uint256 msgValue,
        uint256 minStakeAllowed
    ) external view returns (ValidationResult res, address signer);

    /**
     * @notice Slash a miner stake because their fraud has been proved.
     *   Can only be called by mgr contract
     * @param miner The miner
     * @param blockHash The block hash
     * @param beneficiary The beneficiary, whoever gets rewarded
     */
    function slashMinerForFraud(
        address miner,
        bytes32 blockHash,
        address beneficiary
    ) external;
}
