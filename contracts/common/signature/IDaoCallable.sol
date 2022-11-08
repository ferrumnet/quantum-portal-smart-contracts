// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

interface IDaoCallable {
    function daoAction(bytes32 action, bytes calldata parameters) external;
}