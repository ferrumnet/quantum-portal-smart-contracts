// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {UUPSUpgradeable, Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {MultiSigCheckableUpgradeable} from "foundry-contracts/contracts/contracts-upgradeable/signature/MultiSigCheckableUpgradeable.sol";
import {IQuantumPortalAuthorityMgr} from "./IQuantumPortalAuthorityMgr.sol";
import {IQuantumPortalFinalizerPrecompile, QUANTUM_PORTAL_PRECOMPILE} from "./IQuantumPortalFinalizerPrecompile.sol";
import {LibChainCheck} from "../utils/LibChainCheck.sol";
import {QuantumPortalWorkPoolServerUpgradeable, IQuantumPortalWorkPoolServer} from "./QuantumPortalWorkPoolServerUpgradeable.sol";
import {QuantumPortalWorkPoolClientUpgradeable} from "./QuantumPortalWorkPoolClientUpgradeable.sol";
import {IOperatorRelation, OperatorRelationUpgradeable} from "./stake/OperatorRelationUpgradeable.sol";
import {MultiSigLib} from "foundry-contracts/contracts/contracts/signature/MultiSigLib.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


error OperatorHasNoValidator(address operator);
error SignaturesAreNoteSorted(address lastSigner, address signer);
error NotEnoughSignatures(uint256 minSignatures, uint256 signatures);
error SignarureIsEmpty(bytes signature);

/**
 @notice Authority manager, provides authority signature verification, for 
    different actions.
 */
contract QuantumPortalAuthorityMgrUpgradeable is
    Initializable,
    UUPSUpgradeable,
    EIP712Upgradeable,
    QuantumPortalWorkPoolClientUpgradeable,
    QuantumPortalWorkPoolServerUpgradeable,
    MultiSigCheckableUpgradeable,
    OperatorRelationUpgradeable,
    IQuantumPortalAuthorityMgr
{
    string public constant NAME = "FERRUM_QUANTUM_PORTAL_AUTHORITY_MGR";
    string public constant VERSION = "000.001";
    bytes32 constant VALIDATE_AUTHORITY_SIGNATURE =
        keccak256(
            "ValidateAuthoritySignature(uint256 action,bytes32 msgHash,bytes32 salt,uint64 expiry)"
        );

    function initialize(
        address _ledgerMgr,
        address _portal,
        address initialOwner,
        address initialAdmin
    ) public initializer {
        __EIP712_init(NAME, VERSION);
        __QuantimPortalWorkPoolServer_init(_ledgerMgr, _portal, initialOwner, initialAdmin);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
    
    /**
     * @notice Validates the authority signature
     * @param action The action
     * @param msgHash The message hash (summary of the object to be validated)
     * @param salt A unique salt
     * @param expiry Signature expiry
     * @param signature The signatrue
     */
    function validateAuthoritySignature(
        Action action,
        bytes32 msgHash,
        bytes32 salt,
        uint64 expiry,
        bytes memory signature
    ) external override onlyMgr returns (address[] memory validators) {
        require(action != Action.NONE, "QPAM: action required");
        require(msgHash != bytes32(0), "QPAM: msgHash required");
        require(salt != 0, "QPAM: salt required");
        require(expiry > block.timestamp, "QPAM: already expired");
        require(signature.length != 0, "QPAM: signature required");
        bytes32 message = keccak256(
            abi.encode(
                VALIDATE_AUTHORITY_SIGNATURE,
                uint256(action),
                msgHash,
                salt,
                expiry
            )
        );
        bool result;
        bytes32 digest = _hashTypedDataV4(message);
        (result, validators) = tryVerifyDigestWithAddressWithMinSigCheckForOperators(digest, signature);
        require(result, "QPAM: invalid signature");

        // Set the salt as used
        MultiSigCheckableStorageV001 storage $$ = _getMultiSigCheckableStorageV001();
        require(!$$.usedHashes[salt], "MSC: Message already used");
        $$.usedHashes[salt] = true;
    }

    /**
     * @notice Withdraw fees collected for the validator on the remote chain
     * @param remoteChain The remote chain
     * @param to The address to receive funds
     * @param worker The worker
     * @param fee The fee
     */
    function withdraw(uint256 remoteChain, address to, address worker, uint fee) external {
        withdraw(
            IQuantumPortalWorkPoolServer.withdrawVariableRemote.selector,
            remoteChain,
            to,
            worker,
            fee
        );
    }

    /**
     @notice Wrapper function for MultiSigCheckable.initialize, performs an additional precompile call to register finalizers
     if on QPN chain.
     */
    function initializeQuoromAndRegisterFinalizer(
        address quorumId,
        uint64 groupId,
        uint16 minSignatures,
        uint8 ownerGroupId,
        address[] calldata addresses
    ) external {
        
        // first initialize the quorom
        initializeQuorum(quorumId, groupId, minSignatures, ownerGroupId, addresses);

        // if QPN testnet or mainnet, ensure the precompile is called
        if (LibChainCheck.isFerrumChain()) {
            for (uint i=0; i<addresses.length; i++) {
                bytes memory payload = abi.encodeWithSelector(
                    IQuantumPortalFinalizerPrecompile.registerFinalizer.selector,
                    block.chainid,
                    addresses[i]
                );

                (bool success, bytes memory returnData) = QUANTUM_PORTAL_PRECOMPILE.call(payload);
                if (!success) {
                    if (returnData.length > 0) { // Bubble up the revert reason
                        assembly {
                            let returnDataSize := mload(returnData)
                            revert(add(32, returnData), returnDataSize)
                        }
                    } else {
                        revert("QPAM: fail register");
                    }
                }
            }
        }
    }

    /**
     @notice Returns if the digest can be verified. It maps the signers to the delegates after verifying the signatures.
     @param digest The digest
     @param multiSignature The signatures formatted as a multisig. Note that this
        format requires signatures to be sorted in the order of signers (as bytes)
     @return result Identifies success or failure
     @return validators Lis of validators.
     */
    function tryVerifyDigestWithAddressWithMinSigCheckForOperators(
        bytes32 digest,
        bytes memory multiSignature
    ) internal view returns (bool result, address[] memory validators) {
        MultiSigCheckableStorageV001 storage $ = _getMultiSigCheckableStorageV001();
        if (multiSignature.length == 0) {
            revert SignarureIsEmpty(multiSignature);
        }
        MultiSigLib.Sig[] memory signatures = MultiSigLib.parseSig(
            multiSignature
        );
        if (signatures.length == 0) {
            revert SignarureIsEmpty(multiSignature);
        }
        validators = new address[](signatures.length);

        address _signer = ECDSA.recover(
            digest,
            signatures[0].v,
            signatures[0].r,
            signatures[0].s
        );
        address lastSigner = _signer;

        OperatorRelationStorageV001 storage $opRel = _getOperatorRelationStorageV001();
        IOperatorRelation.Relationship memory sigerDelegate = $opRel.delegateLookup[_signer];
        if (sigerDelegate.delegate == address(0) || sigerDelegate.deleted == 1) {
            revert OperatorHasNoValidator(_signer);
        }
        validators[0] = sigerDelegate.delegate;
        address quorumId = $.quorumSubscriptions[sigerDelegate.delegate].id;
        if (quorumId == address(0)) {
            return (false, new address[](0));
        }
        Quorum memory q = $.quorums[quorumId];
        for (uint256 i = 1; i < signatures.length; i++) {
            _signer = ECDSA.recover(
                digest,
                signatures[i].v,
                signatures[i].r,
                signatures[i].s
            );
            sigerDelegate = $opRel.delegateLookup[_signer];
            if (sigerDelegate.delegate == address(0) || sigerDelegate.deleted == 1) {
                revert OperatorHasNoValidator(_signer);
            }
            quorumId = $.quorumSubscriptions[sigerDelegate.delegate].id;
            if (quorumId == address(0)) {
                return (false, new address[](0));
            }
            require(
                q.id == quorumId,
                "MSC: all signers must be of same quorum"
            );

            validators[i] = sigerDelegate.delegate;
            // This ensures there are no duplicate signers
            if (lastSigner >= _signer) {
                revert SignaturesAreNoteSorted(lastSigner, _signer);
            }
            lastSigner = _signer;
        }

        if (validators.length < q.minSignatures) {
            revert NotEnoughSignatures(q.minSignatures, validators.length);
        }
        return (true, validators);
    }
}
