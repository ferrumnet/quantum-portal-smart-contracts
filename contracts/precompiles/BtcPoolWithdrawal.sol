// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.3;

/// @dev The Btc pools precompile contract's address.
address constant BTC_POOLS_ADDRESS = 0x0000000000000000000000000000000000000812;

/**
 * @title BtcPools
 * @dev Interface for interacting with the BtcPools contract.
 */
interface BtcPoolsWithdrawal {
    /**
     * @notice Submit a withdrawal request to the Bitcoin pools.
     * @dev This function allows a user to initiate a withdrawal request by providing the destination Bitcoin address and the withdrawal amount.
     * @param _address The destination Bitcoin address where the withdrawn funds will be sent.
     * @param _amount The amount of Bitcoin to be withdrawn, represented as a uint32.
     */
    function submitWithdrawalRequest(
        bytes32 _address,
        uint32 _amount
    ) external;
}
