// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {FullMath} from "foundry-contracts/contracts/contracts/math/FullMath.sol";
import {SafeAmount} from "foundry-contracts/contracts/contracts/common/SafeAmount.sol";
import {FixedPoint128} from "foundry-contracts/contracts/contracts/math/FixedPoint128.sol";
import {IQuantumPortalWorkPoolClient} from "../../../../quantumPortal/poc/poa/IQuantumPortalWorkPoolClient.sol";
import {WithQpUpgradeable} from "../utils/WithQpUpgradeable.sol";
import {WithRemotePeersUpgradeable} from "../utils/WithRemotePeersUpgradeable.sol";
import {WithLedgerMgrUpgradeable} from "../utils/WithLedgerMgrUpgradeable.sol";


/**
 * @notice Record amount of work done, and distribute rewards accordingly.
 */
abstract contract QuantumPortalWorkPoolClientUpgradeable is
    Initializable, IQuantumPortalWorkPoolClient, WithQpUpgradeable, WithLedgerMgrUpgradeable, WithRemotePeersUpgradeable
{
    /// @custom:storage-location erc721:ferrum.storage.quantumportalworkpoolclient.001
    struct QuantumPortalWorkPoolClientStorageV001 {
        mapping(uint256 => mapping(address => uint256)) works;
        mapping(uint256 => uint256) totalWork;
        mapping(uint256 => uint256) remoteEpoch;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.quantumportalworkpoolclient.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant QuantumPortalWorkPoolClientStorageV001Location = 0x520647edf12ebb48d9dac15f3821eeaa604d322d0ac462cde2ccdd4af021f900;

    function __QuantumPortalWorkPoolClient_init(
        address ledgerMgr,
        address _portal,
        address initialOwner,
        address initialAdmin
    ) internal onlyInitializing {
        __WithLedgerMgr_init_unchained(ledgerMgr);
        __WithQp_init_unchained(_portal);
        __WithAdmin_init(initialOwner, initialAdmin);
    }

    function works(uint256 remoteChain, address worker) public view returns (uint256) {
        return _getQuantumPortalWorkPoolClientStorageV001().works[remoteChain][worker];
    }

    function totalWork(uint256 remoteChain) public view returns (uint256) {
        return _getQuantumPortalWorkPoolClientStorageV001().totalWork[remoteChain];
    }

    function remoteEpoch(uint256 remoteChain) public view returns (uint256) {
        return _getQuantumPortalWorkPoolClientStorageV001().remoteEpoch[remoteChain];
    }

    /**
     * @inheritdoc IQuantumPortalWorkPoolClient
     */
    function registerWork(
        uint256 remoteChain,
        address worker,
        uint256 work,
        uint256 _remoteEpoch
    ) external override onlyMgr {
        QuantumPortalWorkPoolClientStorageV001 storage $ = _getQuantumPortalWorkPoolClientStorageV001();
        $.works[remoteChain][worker] += work;
        $.totalWork[remoteChain] += work;
        $.remoteEpoch[remoteChain] = _remoteEpoch;
    }

    /**
     * @notice Withdraw the rewards on the remote chain. Note: in case of
     * tx failure the funds are gone. So make sure to provide enough fees to ensure the 
     * tx does not fail because of gas.
     * @param selector The selector
     * @param remoteChain The remote
     * @param to Send the rewards to
     * @param worker The worker
     * @param fee The multi-chain transaction fee
     */
    function withdraw(
        bytes4 selector,
        uint256 remoteChain,
        address to,
        address worker,
        uint fee
    ) internal {
        QuantumPortalWorkPoolClientStorageV001 storage $ = _getQuantumPortalWorkPoolClientStorageV001();
        uint256 work = $.works[remoteChain][worker];
        delete $.works[remoteChain][worker];
        // Send the fee
        require(
            SafeAmount.safeTransferFrom(
                portal().feeToken(),
                msg.sender,
                portal().feeTarget(),
                fee
            ) != 0,
            "QPWPC: fee required"
        );
        uint256 workRatioX128 = FullMath.mulDiv(
            work,
            FixedPoint128.Q128,
            $.totalWork[remoteChain]
        );
        uint256 epoch = $.remoteEpoch[remoteChain];
        bytes memory method = abi.encodeWithSelector(
            selector,
            to,
            workRatioX128,
            epoch
        );
        address serverContract = remotePeers(remoteChain);
        portal().run(uint64(remoteChain), serverContract, msg.sender, method);
    }

    function _getQuantumPortalWorkPoolClientStorageV001() internal pure returns (QuantumPortalWorkPoolClientStorageV001 storage $) {
        assembly {
            $.slot := QuantumPortalWorkPoolClientStorageV001Location
        }
    }
}
