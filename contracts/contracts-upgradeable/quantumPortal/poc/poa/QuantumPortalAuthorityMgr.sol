// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {UUPSUpgradeable, Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {MultiSigCheckable} from "foundry-contracts/contracts/contracts-upgradeable/signature/MultiSigCheckable.sol";
import {IQuantumPortalAuthorityMgr} from "../../../../quantumPortal/poc/poa/IQuantumPortalAuthorityMgr.sol";
import {IQuantumPortalFinalizerPrecompile, QUANTUM_PORTAL_PRECOMPILE} from "../../../../quantumPortal/poc/poa/IQuantumPortalFinalizerPrecompile.sol";
import {QuantumPortalWorkPoolServer, IQuantumPortalWorkPoolServer} from "./QuantumPortalWorkPoolServer.sol";
import {QuantumPortalWorkPoolClient} from "./QuantumPortalWorkPoolClient.sol";
import {LibChainCheck} from "../../../../quantumPortal/poc/utils/LibChainCheck.sol";


/**
 @notice Authority manager, provides authority signature verification, for 
    different actions.
 */
contract QuantumPortalAuthorityMgr is
    Initializable,
    UUPSUpgradeable,
    EIP712Upgradeable,
    QuantumPortalWorkPoolClient,
    QuantumPortalWorkPoolServer,
    MultiSigCheckable,
    IQuantumPortalAuthorityMgr
{
    string public constant NAME = "FERRUM_QUANTUM_PORTAL_AUTHORITY_MGR";
    string public constant VERSION = "000.010";
    bytes32 constant VALIDATE_AUTHORITY_SIGNATURE =
        keccak256(
            "ValidateAuthoritySignature(uint256 action,bytes32 msgHash,bytes32 salt,uint64 expiry)"
        );

    function initialize(
        address ledgerMgr,
        address _portal,
        address initialOwner,
        address initialAdmin
    ) public initializer {
        __EIP712_init(NAME, VERSION);
        __QuantimPortalWorkPoolServer_init(ledgerMgr, _portal, initialOwner, initialAdmin);        
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
    ) external override onlyMgr {
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
        verifyUniqueSalt(message, salt, 1, signature);
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
                IQuantumPortalFinalizerPrecompile(QUANTUM_PORTAL_PRECOMPILE).registerFinalizer(block.chainid, addresses[i]);
            }
        }
    }
}
