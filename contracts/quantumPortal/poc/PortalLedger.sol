// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IQuantumPortalLedgerMgr.sol";
import "foundry-contracts/contracts/common/WithAdmin.sol";
import "./QuantumPortalLib.sol";
import "./QuantumPortalState.sol";

import "hardhat/console.sol";

interface CanEstimateGas {
    function executeTxAndRevertToEstimateGas(address addr, bytes memory method) external;
}

contract PortalLedger is WithAdmin {
    event ExecutionReverted(uint256 remoteChainId, address localContract, bytes32 revertReason);
    address public mgr;
    QuantumPortalState public state;
    QuantumPortalLib.Context public context;
    uint256 immutable internal CHAIN_ID; // To support override

    modifier onlyMgr() {
        require(msg.sender == mgr, "PL: Not allowed");
        _;
    }

    constructor(uint256 overrideChainId) {
        CHAIN_ID = overrideChainId == 0 ? block.chainid : overrideChainId;
    }

    event RemoteTransfer(uint256 chainId, address token, address from, address to, uint256 amount);
    /**
     @notice Executes a transaction within a remote block context
     @param blockIndex The block index
     @param t The remote transaction
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
        if (t.method.length == 0) {
            // This is a withdraw tx. There is no remote balance to be updated.
            // I.e. when the remote contract creates decides to pay out,
            // it reduces the remote balance for itself, and generates a withdraw tx
            // Withdraw txs may not fail. If the actual withdraw failed, there is
            // either an issue with the token, which we cannot do anything about, 
            // or not enough balance, which should never happen.
            console.log("UPDATING BALANCE FOR ", t.remoteContract, t.amount);
            if (t.amount != 0) {
                state.setRemoteBalances(uint256(b.chainId), t.token, t.remoteContract,
                    state.getRemoteBalances(uint256(b.chainId), t.token, t.remoteContract) + t.amount);
            }
        } else {
            QuantumPortalLib.Context memory _context = QuantumPortalLib.Context({
                index: uint64(blockIndex),
                blockMetadata: b,
                transaction: t,
                uncommitedBalance: state.getRemoteBalances(b.chainId, t.token, t.remoteContract) + t.amount
            });

            context = _context;
            // update remote balance for the remote contract
            // based on tokens
            // then run the method. If failed, revert the balances
            bool success = callRemoteMethod(b.chainId, t.remoteContract, t.remoteContract, t.method, gas);
            if (success) {
                // Commit the uncommitedBalance. This could have been changed during callRemoteMehod
                uint256 oldBal = state.getRemoteBalances(uint256(b.chainId), t.token, t.remoteContract);
                state.setRemoteBalances(b.chainId, t.token, t.remoteContract, context.uncommitedBalance);
                if (context.uncommitedBalance > oldBal) {
                    emit RemoteTransfer(b.chainId, t.token, t.sourceMsgSender, t.remoteContract, context.uncommitedBalance - oldBal);
                }
            } else {
                // We cannot revert because we don't know where to get the fee from.
                // TODO:
                // revertRemoteBalance(_context);
            }
            resetContext();
        }
        uint postGas = gasleft();
        gasUsed = preGas - postGas;
        console.log("gas used? ", postGas);
    }

    function rejectRemoteTransaction(
        uint256 sourceChainId,
        QuantumPortalLib.RemoteTransaction memory t,
        uint256 gas
    ) external onlyMgr returns (uint256 gasUsed) {
        uint preGas = gasleft();
        console.log("REJECTING...", preGas);
        console.log("AMOUNT", t.amount);
        console.log("REMOTE CONTRACT", t.remoteContract);
        console.log("USING GAS", gas);

        //Refund the remote value to the beneficiary
        if (t.amount != 0) {
            state.setRemoteBalances(sourceChainId, t.token, t.sourceBeneficiary,
                state.getRemoteBalances(sourceChainId, t.token, t.sourceBeneficiary) + t.amount);
        }

        uint postGas = gasleft();
        gasUsed = preGas - postGas;
        console.log("gas used? ", postGas);
    }

    function estimateGasForRemoteTransaction(
        uint256 remoteChainId,
        address sourceMsgSender,
        address remoteContract,
        address beneficiary,
        bytes memory method,
        address token,
        uint256 amount
    ) external {
        QuantumPortalLib.RemoteTransaction memory t = QuantumPortalLib.RemoteTransaction({
            timestamp: uint64(block.timestamp),
            remoteContract: remoteContract,
            sourceMsgSender: sourceMsgSender,
            sourceBeneficiary: beneficiary,
            token: token,
            amount: amount,
            method: method,
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
            uncommitedBalance: state.getRemoteBalances(b.chainId, t.token, t.remoteContract) + t.amount
        });

        context = _context;
        // This call will revert after execution but the tx should go through, hence enabling gas estimation
        address(this).call(abi.encodeWithSelector(CanEstimateGas.executeTxAndRevertToEstimateGas.selector, t.remoteContract, t.method));
        resetContext();
    }

    function executeTxAndRevertToEstimateGas(address addr, bytes memory method) public {
        addr.call(method);
        revert();
    }

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

    function clearContext() external onlyMgr {
        delete context.blockMetadata;
        delete context.transaction;
        delete context;
    }

    function setManager(address _mgr, address _state) external onlyAdmin {
        mgr = _mgr;
        state = QuantumPortalState(_state);
    }

    function revertRemoteBalance(QuantumPortalLib.Context memory _context) internal {
        // Register a revert transaction to be mined
        // TODO: Where does the gas come from?
        IQuantumPortalLedgerMgr(mgr).registerTransaction(
            _context.blockMetadata.chainId,
            _context.transaction.sourceBeneficiary,
            address(0),
            address(0),
            _context.transaction.token,
            _context.transaction.amount,
            "");
    }

    function callRemoteMethod(
        uint256 remoteChainId, address localContract, address addr, bytes memory method, uint256 gas
    ) private returns (bool success) {
        if (method.length == 0) {
            return true;
        }
        // TODO: What happens if addr does not exist or is an address
        // TODO: Include gas properly, and catch the proper error when there is not enough gas
        bytes memory data;
        console.log("CALLING ", addr);
        (success, data) = addr.call{gas: gas}(method);
        // (success, data) = addr.call(method);
        if (!success) {
            bytes32 revertReason = extractRevertReasonSingleBytes32(data);
            console.log("CALL TO CONTRACT FAILED");
            console.logBytes32(revertReason);
            emit ExecutionReverted(remoteChainId, localContract, revertReason);
        }
    }

    /**
     @notice extracts the revert reason. First bytes32
     */
    function extractRevertReasonSingleBytes32 (
        bytes memory revertData
    ) internal pure returns (bytes32 reason) {
        if (revertData.length < 4) {
            // case 1: catch all
            return "No revert message";
        } else {
            bytes4 errorSelector;
            if (errorSelector == bytes4(0x4e487b71) /* `seth sig "Panic(uint256)"` */) {

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
                        and(reasonWord, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000),
                        or(e2, e1))
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

    function resetContext() private {
        delete context;
    }
}