// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IQuantumPortalLedgerMgr.sol";
import "foundry-contracts/contracts/common/WithAdmin.sol";
import "./QuantumPortalLib.sol";
import "hardhat/console.sol";

contract PortalLedger is WithAdmin {
    event ExecutionReverted(uint256 remoteChainId, address localContract, bytes32 revertReason);
    address public mgr;
    mapping(uint256 => mapping(address => mapping(address => uint256))) remoteBalances;
    QuantumPortalLib.Context public context;
    uint256 immutable internal CHAIN_ID; // To support override

    modifier onlyMgr() {
        require(msg.sender == mgr, "PL: Not allowed");
        _;
    }

    constructor(uint256 overrideChainId) {
        CHAIN_ID = overrideChainId == 0 ? block.chainid : overrideChainId;
    }

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
        uint preGas = block.gaslimit;
        console.log("Executing");
        console.log("amount", t.amount);
        console.log("remoteContract", t.remoteContract);
        if (t.method.length == 0) {
            // This is a withdraw tx. There is no remote balance to be updated.
            // I.e. when the remote contract creates decides to pay out,
            // it reduces the remote balance for itself, and generates a withdraw tx
            // Withdraw txs may not fail. If the actual withdraw failed, there is
            // either an issue with the token, which we cannot do anything about, 
            // or not enough balance, which should never happen.
            console.log("UPDATING BALANCE FOR ", t.remoteContract);
            if (t.amount != 0) {
                remoteBalances[CHAIN_ID][t.token][t.remoteContract] += t.amount;
            }
        } else {
            QuantumPortalLib.Context memory _context = QuantumPortalLib.Context({
                index: uint64(blockIndex),
                blockMetadata: b,
                transaction: t,
                uncommitedBalance: remoteBalances[b.chainId][t.token][t.remoteContract] + t.amount
            });

            context = _context;
            // update remote balance for the remote contract
            // based on tokens
            // then run the method. If failed, revert the balances
            bool success = callRemoteMethod(b.chainId, t.remoteContract, t.remoteContract, t.method, gas);
            if (success) {
                // Commit the uncommitedBalance. This could have been changed during callRemoteMehod
                remoteBalances[b.chainId][t.token][t.remoteContract] = context.uncommitedBalance;
            } else {
                revertRemoteBalance(_context);
            }
        }
        uint postGas = block.gaslimit;
        gasUsed = postGas - preGas;
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
        return remoteBalances[chainId][token][addr];
    }

    function clearContext() external onlyMgr {
        delete context.blockMetadata;
        delete context.transaction;
        delete context;
    }

    function setManager(address _mgr) external onlyAdmin {
        mgr = _mgr;
    }

    function revertRemoteBalance(QuantumPortalLib.Context memory _context) internal {
        // Register a revert transaction to be mined
        IQuantumPortalLedgerMgr(mgr).registerTransaction(
            _context.blockMetadata.chainId,
            _context.transaction.sourceBeneficiary,
            address(0),
            address(0),
            _context.transaction.token,
            _context.transaction.amount,
            _context.transaction.gas, // TODO: Use all the remaining gas on the revert tx
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
        // (success,) = addr.call{gas: gas}(method);
        bytes memory data;
        (success, data) = addr.call{gas: gas}(method);
        if (!success) {
            bytes32 revertReason = extractRevertReasonSingleBytes32(data);
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
}