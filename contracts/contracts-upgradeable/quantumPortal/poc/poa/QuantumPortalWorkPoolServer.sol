// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {FullMath} from "foundry-contracts/contracts/contracts/math/FullMath.sol";
import {IQuantumPortalWorkPoolServer} from "../../../../quantumPortal/poc/poa/IQuantumPortalWorkPoolServer.sol";
import {FixedPoint128} from "foundry-contracts/contracts/contracts/math/FixedPoint128.sol";
import {WithAdmin} from "foundry-contracts/contracts/contracts-upgradeable/common/WithAdmin.sol";
import {TokenReceivable} from "../../../staking/library/TokenReceivable.sol";
import {WithLedgerMgr} from "../utils/WithLedgerMgr.sol";
import {WithQp} from "../utils/WithQp.sol";
import {WithRemotePeers} from "../utils/WithRemotePeers.sol";


/**
 * @notice Collect and distribute rewards
 */
abstract contract QuantumPortalWorkPoolServer is
    Initializable,
    IQuantumPortalWorkPoolServer,
    TokenReceivable,
    WithQp,
    WithLedgerMgr,
    WithRemotePeers
{
    /// @custom:storage-location erc7201:ferrum.storage.quantumportalworkpoolserver.001
    struct QuantumPortalWorkPoolServerStorageV001 {
        address baseToken;
        mapping(uint256 => uint256) lastEpoch;
        mapping(uint256 => uint256) collectedFixedFee;
        mapping(uint256 => uint256) collectedVarFee;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.quantumportalworkpoolserver.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant QuantumPortalWorkPoolServerStorageV001Location = 0x44a2b8c7005ea8d02743b3dceccc467b703d767324b6ff20b2d51ca851ce2b00;

    function __QuantimPortalWorkPoolServer_init(
        address ledgerMgr,
        address _portal,
        address initialOwner,
        address initialAdmin
    ) internal onlyInitializing {
        __WithLedgerMgr_init_unchained(ledgerMgr);
        __WithQp_init_unchained(_portal);
        __WithAdmin_init(initialOwner, initialAdmin);
        __TokenReceivable_init();
        __QuantimPortalWorkPoolServer_init_unchained();
    }

    /**
     * @dev This should never be called directly by child contracts unless WithQp has been initialized first (like above)
     */
    function __QuantimPortalWorkPoolServer_init_unchained() internal onlyInitializing {
        _initialize();
    }



    function baseToken() public view returns (address) {
        return _getQuantumPortalWorkPoolServerStorageV001().baseToken;
    }

    function lastEpoch(uint256 chainId) public view returns (uint256) {
        return _getQuantumPortalWorkPoolServerStorageV001().lastEpoch[chainId];
    }

    function collectedFixedFee(uint256 chainId) public view returns (uint256) {
        return _getQuantumPortalWorkPoolServerStorageV001().collectedFixedFee[chainId];
    }

    function collectedVarFee(uint256 chainId) public view returns (uint256) {
        return _getQuantumPortalWorkPoolServerStorageV001().collectedVarFee[chainId];
    }

    function _getQuantumPortalWorkPoolServerStorageV001() internal pure returns (QuantumPortalWorkPoolServerStorageV001 storage $) {
        assembly {
            $.slot := QuantumPortalWorkPoolServerStorageV001Location
        }
    }

    /**
     * @notice Restricted: Update the base token
     * @param _baseToken The base token address
     */
    function updateBaseToken(
        address _baseToken
    ) external onlyOwner {
        QuantumPortalWorkPoolServerStorageV001 storage $ = _getQuantumPortalWorkPoolServerStorageV001();
        $.baseToken = _baseToken;
    }

    /**
     * @inheritdoc IQuantumPortalWorkPoolServer
     */
    function collectFee(
        uint256 targetChainId,
        uint256 localEpoch,
        uint256 fixedFee
    ) external override onlyMgr returns (uint256 varFee) {
        QuantumPortalWorkPoolServerStorageV001 storage $ = _getQuantumPortalWorkPoolServerStorageV001();
        uint256 collected = sync($.baseToken);
        require(collected >= fixedFee, "QPWPS: Not enough fee");
        $.lastEpoch[targetChainId] = localEpoch;
        $.collectedFixedFee[targetChainId] += fixedFee;
        varFee = collected - fixedFee;
        $.collectedVarFee[targetChainId] += varFee;
    }

    /**
     * @inheritdoc IQuantumPortalWorkPoolServer
     */
    function withdrawFixedRemote(
        address to,
        uint256 workRatioX128,
        uint256 epoch
    ) external override {
        QuantumPortalWorkPoolServerStorageV001 storage $ = _getQuantumPortalWorkPoolServerStorageV001();
        (uint256 remoteChainId, uint256 lastLocalEpoch) = withdrawRemote(epoch);
        uint collected = FullMath.mulDiv(
            $.collectedFixedFee[remoteChainId],
            epoch,
            lastLocalEpoch
        );
        uint amount = FullMath.mulDiv(
            collected,
            workRatioX128,
            FixedPoint128.Q128
        );
        amount = amount;
        $.collectedFixedFee[remoteChainId] -= amount;
        sendToken($.baseToken, to, amount);
    }

    /**
     * @inheritdoc IQuantumPortalWorkPoolServer
     */
    function withdrawVariableRemote(
        address to,
        uint256 workRatioX128,
        uint256 epoch
    ) external override {
        QuantumPortalWorkPoolServerStorageV001 storage $ = _getQuantumPortalWorkPoolServerStorageV001();
        (uint256 remoteChainId, uint256 lastLocalEpoch) = withdrawRemote(epoch);
        uint collected = FullMath.mulDiv(
            $.collectedVarFee[remoteChainId],
            epoch,
            lastLocalEpoch
        );
        uint amount = FullMath.mulDiv(
            collected,
            workRatioX128,
            FixedPoint128.Q128
        );
        $.collectedVarFee[remoteChainId] -= amount;
        sendToken($.baseToken, to, amount);
    }

    function _initialize() internal {
        QuantumPortalWorkPoolServerStorageV001 storage $ = _getQuantumPortalWorkPoolServerStorageV001();
        $.baseToken = portal().feeToken();
    }

    /**
     * @notice Withdraw rewards on the remote chain
     * @param epoch The local epoch
     * @return remote chain ID
     * @return last local epoch
     */
    function withdrawRemote(
        uint256 epoch
    ) internal view returns (uint256, uint256) {
        QuantumPortalWorkPoolServerStorageV001 storage $ = _getQuantumPortalWorkPoolServerStorageV001();
        (
            uint256 remoteChainId,
            address sourceMsgSender /* address beneficiary */,

        ) = portal().msgSender();
        // Caller must be a valid pre-configured remote.
        require(sourceMsgSender == remotePeers(remoteChainId), "Not allowed");
        // Worker gets the same ratio of fees compared to the collected fees.
        uint lastLocalEpoch = $.lastEpoch[remoteChainId]; // Note: This can NOT be zero
        require(
            epoch <= lastLocalEpoch,
            "QPWPS:expected epoch<=lastLocalEpoch"
        );
        return (remoteChainId, lastLocalEpoch);
    }
}
