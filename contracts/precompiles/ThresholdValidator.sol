// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.3;

/// @dev The Threshold validator pools precompile contract's address.
address constant THRESHOLD_POOL_ADDRESS = 0x0000000000000000000000000000000000000814;

/**
 * @title ThresholdPools
 * @dev Interface for interacting with the ThresholdPools contract.
 */
interface ThresholdPools {
    /**
     * @dev Registers a threshold validator by submitting relevant data.
     * @param submission The data submitted by the threshold validator (should be the ecdsa pubkey).
     * @notice This function allows external entities to register as threshold validators
     *         by providing the necessary submission data.
     * @dev Requirements:
     * - The submission data must conform to the expected format.
     * - Only authorized entities should call this function.
     * @dev Emits no events. The result of the registration can be observed
     *      by monitoring the state changes in the ThresholdPools contract.
     */
    function registerValidator(
        bytes32 submission
    ) external;
}
