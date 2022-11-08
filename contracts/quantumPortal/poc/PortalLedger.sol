// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IQuantumPortalLedgerMgr.sol";
import "../../common/WithAdmin.sol";
import "./QuantumPortalLib.sol";
import "hardhat/console.sol";

contract PortalLedger is WithAdmin {
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
            bool success = callRemoteMethod(t.remoteContract, t.method, gas);
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

    function revertRemoteBalance(QuantumPortalLib.Context memory context) internal {
        // Register a revert transaction to be mined
        IQuantumPortalLedgerMgr(mgr).registerTransaction(
            context.blockMetadata.chainId,
            context.transaction.sourceBeneficiary,
            address(0),
            address(0),
            context.transaction.token,
            context.transaction.amount,
            context.transaction.gas, // TODO: Use all the remaining gas on the revert tx
            "");
    }

    function callRemoteMethod(address addr, bytes memory method, uint256 gas) private returns (bool success) {
        if (method.length == 0) {
            return true;
        }
        // TODO: What happens if addr does not exist or is an address
        // TODO: Include gas properly, and catch the proper error when there is not enough gas
        // (success,) = addr.call{gas: gas}(method);
        bytes memory data;
        (success, data) = addr.call(method);
        if (!success) {
            string memory revertReason = extractRevertReason(data);
            // TODO: Include the revert reason in the revert response somehow
            console.logString(revertReason);
        }
    }

    /**
     @notice extracts the revert reason. TODO: Limit the size to reduce gas usage
     */
    function extractRevertReason (
        bytes memory revertData
    ) internal pure returns (string memory reason) {
        uint l = revertData.length;
        if (l > 68 + 32) {
            l = 68 + 32;
        }
        uint t;
        assembly {
            revertData := add (revertData, 4)
            t := mload (revertData) // Save the content of the length slot
            mstore (revertData, sub (l, 4)) // Set proper length
        }
        reason = abi.decode (revertData, (string));
        assembly {
            mstore (revertData, t) // Restore the content of the length slot
        }
    }
}