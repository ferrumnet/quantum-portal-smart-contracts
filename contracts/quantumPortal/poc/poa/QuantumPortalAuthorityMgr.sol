// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IQuantumPortalAuthorityMgr.sol";
import "foundry-contracts/contracts/common/IFerrumDeployer.sol";
import "./QuantumPortalWorkPoolServer.sol";
import "./QuantumPortalWorkPoolClient.sol";
import "foundry-contracts/contracts/signature/MultiSigCheckable.sol";
import "./IQuantumPortalFinalizerPrecompile.sol";

/**
 @notice Authority manager, provides authority signature verification, for 
    different actions.
 */
contract QuantumPortalAuthorityMgr is
    IQuantumPortalAuthorityMgr,
    QuantumPortalWorkPoolClient,
    QuantumPortalWorkPoolServer,
    MultiSigCheckable
{
    string public constant NAME = "FERRUM_QUANTUM_PORTAL_AUTHORITY_MGR";
    string public constant VERSION = "000.010";
    bytes32 constant VALIDATE_AUTHORITY_SIGNATURE =
        keccak256(
            "ValidateAuthoritySignature(uint256 action,bytes32 msgHash,bytes32 salt,uint64 expiry)"
        );

    uint256 chainId = block.chainid;

    constructor() EIP712(NAME, VERSION) {
        bytes memory _data = IFerrumDeployer(msg.sender).initData();
        (address _portal, address _mgr) = abi.decode(_data, (address, address));
        WithQp._initializeWithQp(_portal);
        WithLedgerMgr._initializeWithLedgerMgr(_mgr);
    }
    
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
        console.log("verifyUniqueSalt");
        console.logBytes32(message);
        // console.logBytes(salt);
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
        initialize(quorumId, groupId, minSignatures, ownerGroupId, addresses);

        // if QPN testnet or mainnet, ensure the precompile is called
        if (chainId == 26100 || chainId == 26000) {
            for (uint i=0; i<addresses.length; i++) {
                QuantumPortalFinalizerPrecompile(QUANTUM_PORTAL_PRECOMPILE).registerFinalizer(chainId, addresses[i]);
            }
        }
    }
}
