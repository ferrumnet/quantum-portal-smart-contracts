// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFrmFeeManager {
    function payFee(address user, address token, uint256 amount) external returns (bool);
}