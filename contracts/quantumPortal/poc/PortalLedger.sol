// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IQuantumPortalLedgerMgr.sol";
import "./ICanEstimateGas.sol";
import "foundry-contracts/contracts/common/WithAdmin.sol";
import "./QuantumPortalLib.sol";
import "./QuantumPortalState.sol";

import "hardhat/console.sol";

/**
 * @notice Basis of the QP logic for interacting with multi-chain dApps
 *     and providing relevant execution context to them
 */
contract PortalLedger is WithAdmin, ICanEstimateGas {
    address public mgr;
    QuantumPortalState public state;
    QuantumPortalLib.Context public context;
    uint256 internal immutable CHAIN_ID; // To support override

    event RemoteTransfer(
        uint256 chainId,
        address token,
        address from,
        address to,
        uint256 amount
    );

    event ExecutionReverted(
        uint256 remoteChainId,
        address localContract,
        bytes32 revertReason
    );

    /**
     * @notice Can only be called by ledger manager
     */
    modifier onlyMgr() {
        require(msg.sender == mgr, "PL: Not allowed");
        _;
    }

    constructor(uint256 overrideChainId) {
        CHAIN_ID = overrideChainId == 0 ? block.chainid : overrideChainId;
    }

    /**
     @notice Restricted: Executes a transaction within a remote block context
     * @param blockIndex The index of tx in the block
     * @param b The block
     * @param t The transaction
     * @param gas Gas left for execution
     */
    function executeRemoteTransaction(
        uint256 blockIndex,
        QuantumPortalLib.Block memory b,
        QuantumPortalLib.RemoteTransaction memory t,
        uint256 gas
    ) external onlyMgr returns (uint256 gasUsed) {
        uint preGas = gasleft();
        console.log("EXECUTING", preGas);
        console.log("AMOUNT", t.amount);
        console.log("REMOTE CONTRACT", t.remoteContract);
        console.log("USING GAS", gas);
        if (t.methods.length == 0) {
            // This is a withdraw tx. There is no remote balance to be updated.
            // I.e. when the remote contract creates decides to pay out,
            // it reduces the remote balance for itself, and generates a withdraw tx
            // Withdraw txs may not fail. If the actual withdraw failed, there is
            // either an issue with the token, which we cannot do anything about,
            // or not enough balance, which should never happen.
            console.log("UPDATING BALANCE FOR ", t.remoteContract, t.amount);
            if (t.amount != 0) {
                state.setRemoteBalances(
                    uint256(b.chainId),
                    t.token,
                    t.remoteContract,
                    state.getRemoteBalances(
                        uint256(b.chainId),
                        t.token,
                        t.remoteContract
                    ) + t.amount
                );
            }
        } else {
            QuantumPortalLib.Context memory _context = QuantumPortalLib
                .Context({
                    index: uint64(blockIndex),
                    blockMetadata: b,
                    transaction: t,
                    uncommitedBalance: state.getRemoteBalances(
                        b.chainId,
                        t.token,
                        t.remoteContract
                    ) + t.amount
                });

            context = _context;
            // update remote balance for the remote contract
            // based on tokens
            // then run the method. If failed, revert the balances
            bool success = callRemoteMethod(
                b.chainId,
                t.remoteContract,
                t.methods[0], // methods[0] is the call method.
                gas
            );
            if (success) {
                // Commit the uncommitedBalance. This could have been changed during callRemoteMehod
                uint256 oldBal = state.getRemoteBalances(
                    uint256(b.chainId),
                    t.token,
                    t.remoteContract
                );
                state.setRemoteBalances(
                    b.chainId,
                    t.token,
                    t.remoteContract,
                    context.uncommitedBalance
                );
                if (context.uncommitedBalance > oldBal) {
                    emit RemoteTransfer(
                        b.chainId,
                        t.token,
                        t.sourceMsgSender,
                        t.remoteContract,
                        context.uncommitedBalance - oldBal
                    );
                }
            } else {
                _rejectRemoteTransaction(b.chainId, t);
            }
            resetContext();
        }
        uint postGas = gasleft();
        gasUsed = preGas - postGas;
        console.log("gas used? ", postGas);
    }

    /**
     * @notice Restricted: Reject a remote tx and refunds the value
     * @param sourceChainId The source chain ID
     * @param t The remote transaction
     */
    function rejectRemoteTransaction(
        uint256 sourceChainId,
        QuantumPortalLib.RemoteTransaction memory t
    ) external onlyMgr returns (uint256 gasUsed) {
        uint preGas = gasleft();
        console.log("REJECTING...", preGas);
        console.log("AMOUNT", t.amount);
        console.log("REMOTE CONTRACT", t.remoteContract);

        _rejectRemoteTransaction(
            sourceChainId, t);

        uint postGas = gasleft();
        gasUsed = preGas - postGas;
        console.log("gas used? ", postGas);
    }

    /**
     * @notice Estimates gas for remote transaction by simulating then rejecting
     *    a transaction
     * @param remoteChainId The remote chain ID
     * @param sourceMsgSender Source msg sender (source contract)
     * @param remoteContract The contract address on remote chain (this chain)
     * @param beneficiary The beneficiary of the transaction
     * @param method Encoded abi encoded method and parameters to be executed
     * @param token The token on the source chain for value
     * @param amount The amount sent on the source chain
     */
    function estimateGasForRemoteTransaction(
        uint256 remoteChainId,
        address sourceMsgSender,
        address remoteContract,
        address beneficiary,
        bytes memory method,
        address token,
        uint256 amount
    ) external {
        bytes[] memory methods = new bytes[](1);
        methods[0] = method;
        QuantumPortalLib.RemoteTransaction memory t = QuantumPortalLib
            .RemoteTransaction({
                timestamp: uint64(block.timestamp),
                remoteContract: remoteContract,
                sourceMsgSender: sourceMsgSender,
                sourceBeneficiary: beneficiary,
                token: token,
                amount: amount,
                methods: method.length != 0 ? methods : new bytes[](0),
                gas: 0,
                fixedFee: 0
            });
        QuantumPortalLib.Block memory b = QuantumPortalLib.Block({
            chainId: uint64(remoteChainId),
            nonce: 1,
            timestamp: uint64(block.timestamp)
        });
        QuantumPortalLib.Context memory _context = QuantumPortalLib.Context({
            index: uint64(1),
            blockMetadata: b,
            transaction: t,
            uncommitedBalance: state.getRemoteBalances(
                b.chainId,
                t.token,
                t.remoteContract
            ) + t.amount
        });

        context = _context;
        // This call will revert after execution but the tx should go through, hence enabling gas estimation
        (bool result,) = address(this).call(
            abi.encodeWithSelector(
                ICanEstimateGas.executeTxAndRevertToEstimateGas.selector,
                t.remoteContract,
                t.methods[0]
            )
        );
        require(!result);
        resetContext();
    }

    /**
     * @notice Returns the remote balance for an address
     * @param chainId The chain ID
     * @param token The remote token address
     * @param addr The address under query
     * @return The remote balance
     */
    function remoteBalanceOf(
        uint256 chainId,
        address token,
        address addr
    ) external view returns (uint256) {
        QuantumPortalLib.RemoteTransaction memory t = context.transaction;
        if (addr == t.remoteContract && token == t.token) {
            return context.uncommitedBalance;
        }
        return state.getRemoteBalances(chainId, token, addr);
    }

    /**
     * @notice Restricted: Resets the context
     */
    function clearContext() external onlyMgr {
        resetContext();
    }

    /**
     * @notice Restricted: sets the manager
     * @param _mgr The ledger manager
     * @param _state The state contract
     */
    function setManager(address _mgr, address _state) external onlyAdmin {
        mgr = _mgr;
        state = QuantumPortalState(_state);
    }

    /**
     * @inheritdoc ICanEstimateGas
     */
    function executeTxAndRevertToEstimateGas(
        address addr,
        bytes memory method
    ) public override {
        require(msg.sender == address(this)); // Prevent remote calls
        (bool result,) = addr.call(method);
        revert();
    }

    function _rejectRemoteTransaction(
        uint256 sourceChainId,
        QuantumPortalLib.RemoteTransaction memory t
    ) internal {
        //Refund the remote value to the beneficiary
        if (t.amount != 0) {
            state.setRemoteBalances(
                sourceChainId,
                t.token,
                t.sourceBeneficiary,
                state.getRemoteBalances(
                    sourceChainId,
                    t.token,
                    t.sourceBeneficiary
                ) + t.amount
            );
        }
    }

    /**
     * @notice extracts the revert reason. First bytes32
     * @param revertData The revert data. This will be hex encoded
     *     Use this python code to parse it into human readable text:
     *     `bytes.fromhex(hex_string).decode('utf-8')
     * @return reason The frist 32 bytes of the hex-encoded error message
     */
    function extractRevertReasonSingleBytes32(
        bytes memory revertData
    ) internal pure returns (bytes32 reason) {
        if (revertData.length < 4) {
            // case 1: catch all
            return "No revert message";
        } else {
            bytes4 errorSelector;
            assembly {
                errorSelector := mload(add(revertData, 0x20))
            }
            if (
                errorSelector ==
                bytes4(0x4e487b71) /* `seth sig "Panic(uint256)"` */
            ) {
                // case 2: Panic(uint256) (Defined since 0.8.0)
                // solhint-disable-next-line max-line-length
                // ref: https://docs.soliditylang.org/en/v0.8.0/control-structures.html#panic-via-assert-and-error-via-require)
                uint errorCode;
                assembly {
                    errorCode := mload(add(revertData, 0x24))
                    let reasonWord := mload(add(reason, 0x20))
                    // [0..9] is converted to ['0'..'9']
                    // [0xa..0xf] is not correctly converted to ['a'..'f']
                    // but since panic code doesn't have those cases, we will ignore them for now!
                    let e1 := add(and(errorCode, 0xf), 0x30)
                    let e2 := shl(8, add(shr(4, and(errorCode, 0xf0)), 0x30))
                    reasonWord := or(
                        and(
                            reasonWord,
                            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000
                        ),
                        or(e2, e1)
                    )
                    reason := reasonWord
                    // mstore(reason, reasonWord)
                }
            } else {
                if (revertData.length <= 36) {
                    return 0x0;
                }
                // case 3: Error(string) (Defined at least since 0.7.0)
                // case 4: Custom errors (Defined since 0.8.0)
                assembly {
                    reason := mload(add(revertData, 100))
                    // 32 + 4 function selector + 32 data offset + 32 len => First byte of the string
                }
            }
        }
    }

    /**
     * @notice Call the remote method on this chain
     * @param remoteChainId The remote chain ID
     * @param localContract The local contract address
     * @param method The abi-encoded method call
     * @param gas The gas available for execution
     */
    function callRemoteMethod(
        uint256 remoteChainId,
        address localContract,
        bytes memory method,
        uint256 gas
    ) private returns (bool success) {
        if (method.length == 0) {
            return true;
        }
        bytes memory data;
        console.log("CALLING ", localContract);
        (success, data) = localContract.call{gas: gas}(method);
        // (success, data) = addr.call(method);
        if (!success) {
            bytes32 revertReason = extractRevertReasonSingleBytes32(data);
            console.log("CALL TO CONTRACT FAILED");
            console.logBytes32(revertReason);
            emit ExecutionReverted(remoteChainId, localContract, revertReason);
        }
    }

    /**
     * @notice Resets a context
     */
    function resetContext() private {
        delete context;
    }
}
