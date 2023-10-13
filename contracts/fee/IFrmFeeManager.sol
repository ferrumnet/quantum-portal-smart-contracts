// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFrmFeeManager {
    /**
     * @notice Pays the fee on bahalf of the user   
     * @param user The user
     * @param token The token
     * @param amount Amount
     */
    function payFee(address user, address token, uint256 amount) external returns (bool);
}