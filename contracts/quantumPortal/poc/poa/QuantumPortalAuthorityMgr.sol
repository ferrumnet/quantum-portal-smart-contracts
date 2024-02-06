// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IQuantumPortalAuthorityMgr.sol";
import "./IQuantumPortalWorkPoolServer.sol";
import "./IQuantumPortalFinalizerPrecompile.sol";
import "./QuantumPortalWorkPoolClient.sol";
import "foundry-contracts/contracts/signature/MultiSigCheckable.sol";

/**
 @notice Authority manager, provides authority signature verification, for 
    different actions.
 */
contract QuantumPortalAuthorityMgr is
    IQuantumPortalAuthorityMgr,
    QuantumPortalWorkPoolClient,
    MultiSigCheckable
{
    string public constant NAME = "FERRUM_QUANTUM_PORTAL_AUTHORITY_MGR";
    string public constant VERSION = "000.010";

    // signers that have signed a message
    address[] public completedSigners;

    // mapping to check if an address exists in completedSigners
    mapping(address => bool) public alreadySigned;

    // the current msgHash we are checking
    bytes32 public currentMsgHash;

    // the current quorumId we are checking
    address public currentQuorumId;

    uint256 chainId = block.chainid;

    constructor() EIP712(NAME, VERSION) {}

    bytes32 constant VALIDATE_AUTHORITY_SIGNATURE =
        keccak256(
            "ValidateAuthoritySignature(uint256 action,bytes32 msgHash,bytes32 salt,uint64 expiry)"
        );

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
    ) external override {
        require(msg.sender == mgr, "QPAM: unauthorized");
        require(action != Action.NONE, "QPAM: action required");
        require(msgHash != bytes32(0), "QPAM: msgHash required");
        require(expiry != 0, "QPAM: expiry required");
        require(salt != 0, "QPAM: salt required");
        require(expiry > block.timestamp, "QPAM: signature expired");
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
     * @notice Validates the authority signature for a single signer. 
     *  This is to collect signatures one by one
     *  TODO: Elminiate the need for this, and move the logic to the offchain worker
     * @param action The action
     * @param msgHash The message hash (summary of the object to be validated)
     * @param salt A unique salt
     * @param expiry Signature expiry
     * @param signature The signatrue
     */
    function validateAuthoritySignatureSingleSigner(
        Action action,
        bytes32 msgHash,
        bytes32 salt,
        uint64 expiry,
        bytes memory signature
    )
        external
        override
        returns (address[] memory signers, bool quorumComplete)
    {
        require(msg.sender == mgr, "QPAM: unauthorized");
        // ensure that the current msgHash matches the one in process or msgHash is empty
        if (currentMsgHash != bytes32(0)) {
            require(
                msgHash == currentMsgHash,
                "QPAM: msgHash different than expected"
            );
        }

        require(action != Action.NONE, "QPAM: action required");
        require(msgHash != bytes32(0), "QPAM: msgHash required");
        require(expiry != 0, "QPAM: expiry required");
        require(salt != 0, "QPAM: salt required");
        require(expiry > block.timestamp, "QPAM: signature expired");
        bytes32 message = keccak256(
            abi.encode(
                VALIDATE_AUTHORITY_SIGNATURE,
                uint256(action),
                msgHash,
                salt,
                expiry
            )
        );

        // Validate the message for only this signer
        bytes32 digest = _hashTypedDataV4(message);
        bool result;
        (result, signers) = tryVerifyDigestWithAddressWithMinSigCheck(
            digest,
            1,
            signature,
            false
        );
        require(result, "QPAM: Invalid signer");
        require(signers.length == 1, "QPAM: Wrong number of signers");
        address signer = signers[0];

        address signerQuorumId = quorumSubscriptions[signer].id;

        // if first signer, then set quorumId and msgHash
        if (completedSigners.length == 0) {
            currentMsgHash = msgHash;
            currentQuorumId = signerQuorumId;
        } else {
            // check the signer is part of the same quorum
            require(
                signerQuorumId == currentQuorumId,
                "QPAM: Signer quorum mismatch"
            );

            // ensure not a duplicate signer
            require(!alreadySigned[signer], "QPAM: Already Signed!");
        }

        // insert signer to the signers list
        completedSigners.push(signer);
        alreadySigned[signer] = true;

        // if the quorum min length is complete, clear storage and return success
        if (
            completedSigners.length >= quorumSubscriptions[signer].minSignatures
        ) {
            currentMsgHash = bytes32(0);
            currentQuorumId = address(0);

            // remove all signed mapping
            for (uint i = 0; i < completedSigners.length; i++) {
                delete alreadySigned[completedSigners[i]];
            }
            delete completedSigners;
            return (completedSigners, true);
        } else {
            return (completedSigners, false);
        }
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
     * @notice Clears the currentMsgHash to unblock invalid states
     */
    function clearCurrentMsgHash() external {
        currentMsgHash = bytes32(0);
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
