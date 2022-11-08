// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "../../staking/interfaces/IStakeInfo.sol";
import "../Freezable.sol";
import "./MultiSigCheckable.sol";

abstract contract MultiSigProofOfStake is Freezable, MultiSigCheckable {
    address public staking;
    address public stakedToken;

    /**
     @notice Sets the stake contract and its token. Only admin can call this function
     @param stakingContract The staking contract
     @param _stakedToken The staked token
     */
    function setStake(address stakingContract, address _stakedToken) external onlyAdmin freezable {
        require(stakingContract != address(0), "MSPS: stakingContract required");
        require(_stakedToken != address(0), "MSPS: _stakedToken required");
        staking = stakingContract;
        stakedToken = _stakedToken;
    }

    /**
     @notice Verifies a signed message considering staking threshold
     @param message The msg digest
     @param salt The salt
     @param thresholdX100 The staked threshold between 0 and 100
     @param expectedGroupId The group ID signing the request
     @param multiSignature The multisig signatures
     */
    function verifyWithThreshold(
        bytes32 message,
        bytes32 salt,
        uint256 thresholdX100,
        uint64 expectedGroupId,
        bytes memory multiSignature
    ) internal {
        require(multiSignature.length != 0, "MSPS: multiSignature required");
        bytes32 digest = _hashTypedDataV4(message);
        bool result;
        address[] memory signers;
        (result, signers) = tryVerifyDigestWithAddress(digest, expectedGroupId, multiSignature);
        require(result, "MSPS: Invalid signature");
        require(!usedHashes[salt], "MSPS: Message digest already used");
        usedHashes[salt] = true;

        address _staking = staking;
        if (_staking != address(0)) {
            // Once all signatures are verified, make sure we have the staked ratio covered
            address token = stakedToken;
            uint256 stakedTotal = IStakeInfo(_staking).stakedBalance(token);
            uint256 signersStake;
            for(uint256 i=0; i < signers.length; i++) {
                signersStake = signersStake + IStakeInfo(_staking).stakeOf(token, signers[i]);
            }
            require( signersStake * 100 / stakedTotal >= thresholdX100, "MSPS: Staked signatures don't meet the sthreshold");
        }
    }
}