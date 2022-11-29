// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interfaces/IStakeV2.sol";
import "foundary-contracts/contracts/signature/SigCheckable.sol";

// Todo: Use multisig checkable...
abstract contract StakingV2CommonSignatures is SigCheckable {
    bytes32 constant SIGNATURE_FOR_ID_METHOD =
        keccak256("SignatureForId(address id,uint8 stakeType,uint32 signatureLifetime,bytes32 salt)");
    function signatureForId(address id,
        Staking.StakeType stakeType,
        address signer,
        bytes32 salt,
        bytes calldata signature,
        uint32 signatureLifetime) internal {
        require(signatureLifetime < block.timestamp, "SignatureHelper: expired");
        uint8 stInt = uint8(stakeType);
        bytes32 message = keccak256(abi.encode(
            SIGNATURE_FOR_ID_METHOD,
            id,
            stInt,
            signatureLifetime,
            salt));
        address _signer = signerUnique(message, signature);
        require(_signer == signer, "SV2: Invalid signer");
    }

    bytes32 constant VERIFY_ALLOCATION_METHOD =
        keccak256("VerifyAllocation(address id,address allocatee,uint256 amount,bytes32 salt)");
    function verifyAllocation(
        address id,
        address allocatee,
        address allocator,
        uint256 amount,
        bytes32 salt,
        bytes calldata signature) internal view {
        bytes32 message = keccak256(abi.encode(
            VERIFY_ALLOCATION_METHOD,
            id,
            allocatee,
            amount,
            salt));
        (, address _signer) = signer(message, signature);
        require(_signer == allocator, "SV2: Invalid allocator");
    }
}