// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./QuantumPortalLib.sol";

interface IQuantumPortalPoc {

    /**
     * @notice The fee target
     */
    function feeTarget() external view returns (address);

    /**
     * @notice The fee token
     */
    function feeToken() external view returns (address);

    /**
     * @notice Runs a remote transaction
     * @param remoteChain The remote chain ID
     * @param remoteContract The remote contract address
     * @param beneficiary Beneficiary. This is the address that recieves the funds / refunds in
     *   in case the transaction rejected or failed
     * @param remoteMethodCall Abi encoded remote method call
     */
    function runNativeFee(
        uint64 remoteChain,
        address remoteContract,
        address beneficiary,
        bytes memory remoteMethodCall
    ) external payable;

    /**
     * @notice Runs a remote transaction
     * @param remoteChain The remote chain ID
     * @param remoteContract The remote contract address
     * @param beneficiary Beneficiary. This is the address that recieves the funds / refunds in
     *   in case the transaction rejected or failed
     * @param remoteMethodCall Abi encoded remote method call
     */
    function run(
        uint64 remoteChain,
        address remoteContract,
        address beneficiary,
        bytes memory remoteMethodCall
    ) external;

    /**
     * @notice Runs a remote transaction. This can be called by the token sending the value.
     *   Specially useful for specialized tokens or non-evm chains.
     *   This will trust that the amount is transferred to QP and delegates the management
     *   of the remote balances to the token itself.
     * @param remoteChain The remote chain ID
     * @param remoteContract The remote contract address
     * @param beneficiary Beneficiary. This is the address that recieves the funds / refunds in
     *   in case the transaction rejected or failed
     * @param method The encoded method to call
     */
    function runFromTokenNativeFee(
        uint64 remoteChain,
        address remoteContract,
        address beneficiary,
        bytes memory method,
        uint256 amount
    ) external payable;

    /**
     * @notice Runs a remote transaction. This can be called by the token sending the value.
     *   Specially useful for specialized tokens or non-evm chains.
     *   This will trust that the amount is transferred to QP and delegates the management
     *   of the remote balances to the token itself.
     * @param remoteChain The remote chain ID
     * @param remoteContract The remote contract address
     * @param beneficiary Beneficiary. This is the address that recieves the funds / refunds in
     *   in case the transaction rejected or failed
     * @param method The encoded method to call
     */
    function runFromToken(
        uint64 remoteChain,
        address remoteContract,
        address beneficiary,
        bytes memory method,
        uint256 amount
    ) external;

    /**
     * @notice Runs a remote transaction and passes tokens to the remote contract
     * @param remoteChain The remote chain ID
     * @param remoteContract The remote contract address
     * @param beneficiary Beneficiary. This is the address that recieves the funds / refunds in
     *   in case the transaction rejected or failed
     * @param token The token to send to the remote contract
     * @param method The encoded method to call
     */
    function runWithValueNativeFee(
        uint64 remoteChain,
        address remoteContract,
        address beneficiary,
        address token,
        bytes memory method
    ) external payable;

    /**
     * @notice Runs a remote transaction and passes tokens to the remote contract
     * @param remoteChain The remote chain ID
     * @param remoteContract The remote contract address
     * @param beneficiary Beneficiary. This is the address that recieves the funds / refunds in
     *   in case the transaction rejected or failed
     * @param token The token to send to the remote contract
     * @param method The encoded method to call
     */
    function runWithValue(
        uint64 remoteChain,
        address remoteContract,
        address beneficiary,
        address token,
        bytes memory method
    ) external;

    /**
     * @notice Runs a withdraw command on the remote chain
     * @param remoteChainId The remote chain ID
     * @param remoteAddress The receiver remote address
     * @param token The remote token to withdraw
     * @param amount The amount to withrdraw
     */
    function runWithdraw(
        uint64 remoteChainId,
        address remoteAddress,
        address token,
        uint256 amount
    ) external;

    /**
     * @notice Returns the message sender structure from QP.
     *     This must be called within the context of a multi-chain tx execution
     * @return sourceNetwork The source network
     * @return sourceMsgSender The source message sender. Usually the calling contract
     * @return sourceBeneficiary The beneficary. Usually the address that the source
     *     contract has used
     */
    function msgSender()
        external
        view
        returns (
            uint256 sourceNetwork,
            address sourceMsgSender,
            address sourceBeneficiary
        );

    /**
     * @notice The multi-chain transaction context
     */
    function txContext()
        external
        view
        returns (QuantumPortalLib.Context memory);

    /**
     * @notice Transfer remote token balances. This can be called within
     *    the multi-chain tx execution context
     * @param chainId The chain ID
     * @param token The remote token tok transfer
     * @param to Receiver address
     * @param amount The amount to transfer
     */
    function remoteTransfer(
        uint256 chainId,
        address token,
        address to,
        uint256 amount
    ) external;

    /**
     * @notice This allows contracts to pay out tokens from their local balance.
     *    if the calling chain is the same chain as the transfer.
     *    Unlike `remoteTransfer` this method calls the actual `transfer` on the token
     * TODO: Carefully consider all attack vectors...
     * @param token The remote token tok transfer
     * @param to Receiver address
     * @param amount The amount to transfer
     */
    function localTransfer(
        address token,
        address to,
        uint256 amount
    ) external;
}
