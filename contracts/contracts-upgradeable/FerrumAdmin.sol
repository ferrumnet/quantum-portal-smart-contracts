// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MultiSigCheckable} from "foundry-contracts/contracts/contracts/signature/MultiSigCheckable.sol";


/**
 * @title FerrumAdmin
 * @notice Intended to be inherited by Quantum Portal Gateway contract
 */
abstract contract FerrumAdmin is MultiSigCheckable {

    // HARDCODE THESE TO VALUES SUCH THAT TIMELOCKED_PROD > PROD > BETA
    address constant BETA_QUORUMID = address(123);
    address constant PROD_QUORUMID = address(456);
    address constant TIMELOCKED_PROD_QUORUMID = address(789);

    uint256 timelockPeriod = 3 days;

    mapping(address => bool) public devAccounts;
    mapping(bytes32 => PermittedCall) public permittedCalls;
    mapping(bytes32 => address) private minRequiredAuth; // 0x{4byteFuncSelector}0000000000000000{20byteQPContractAddress} => QUORUMID

    struct MinAuthSetting {
        address quorumId;
        address target;
        bytes4 funcSelector;
    }

    struct PermittedCall {
        bool isPermitted;
        uint120 executableFrom;
        uint120 expiry;
    }

    struct InitQuorum {
        uint16 minSignatures;
        address[] addresses;
    }

    event DevAccountAdded(address indexed account);
    event DevAccountRemoved(address indexed account);
    event CallPermitted(bytes32 indexed callHash, address indexed target, bytes data);
    event CallExecuted(bytes32 indexed callHash, address indexed target, bytes data);

    modifier onlyDevs() {
        require(devAccounts[msg.sender], "Only devs can execute");
        _;
    }

    modifier onlyDevsOrAdmin() {
        require(devAccounts[msg.sender] || msg.sender == owner(), "Only devs or admin can add/remove dev accounts");
        _;
    }

    /**
     * @dev Always pass in the Quorums array in this order:
     * index 0: BETA_QUORUMID
     * index 1: PROD_QUORUMID
     * index 2: TIMELOCKED_PROD_QUORUMID
     * @param quorums Array of quorums to initialize
     */
    constructor(InitQuorum[] memory quorums, MinAuthSetting[] memory settings) {
        _initializeQuorum(BETA_QUORUMID, 0, quorums[0].minSignatures, 0, quorums[0].addresses);
        _initializeQuorum(PROD_QUORUMID, 0, quorums[1].minSignatures, 0, quorums[1].addresses);
        _initializeQuorum(TIMELOCKED_PROD_QUORUMID, 0, quorums[2].minSignatures, 0, quorums[2].addresses);

        _setCallAuthLevels(settings);
    }

    function permitCall(
        address target,
        bytes calldata data,
        bytes32 salt,
        uint64 expiry,
        bytes memory multiSignature,
        address quorumId
    ) external {
        bytes32 callHash = keccak256(abi.encode(target, data, salt));

        // Verify
        require(expiry < block.timestamp + 7 days, "Expiry too far");
        _validateAuthLevel(target, data, quorumId);
        verifyUniqueSaltWithQuorumId(callHash, quorumId, salt, 0, multiSignature);

        // Store the permitted call
        uint120 excecutableFrom = quorumId == TIMELOCKED_PROD_QUORUMID ?
            uint120(block.timestamp + timelockPeriod) :
            uint120(block.timestamp);
        
        permittedCalls[callHash] = PermittedCall(true, excecutableFrom, expiry);

        emit CallPermitted(callHash, target, data);
    }

    function executePermittedCall(
        address target,
        bytes calldata data,
        bytes32 salt
    ) external onlyDevs {
        // Hash the call details
        bytes32 callHash = keccak256(abi.encode(target, data, salt));

        // Ensure the call is permitted
        require(permittedCalls[callHash].isPermitted, "Call not permitted");
        require(block.timestamp < permittedCalls[callHash].expiry, "Permitted call expired");
        require(block.timestamp >= permittedCalls[callHash].executableFrom, "Call not executable yet");

        // Execute the call
        (bool success, ) = target.call(data);
        require(success, "Call execution failed");

        // Clear the permitted call
        delete permittedCalls[callHash];

        emit CallExecuted(callHash, target, data);
    }

    function addDevAccounts(address[] memory account) external onlyDevsOrAdmin {
        for (uint i = 0; i < account.length; i++) {
            if(devAccounts[account[i]]) continue; // Prevents redundant event emission
            devAccounts[account[i]] = true;
            emit DevAccountAdded(account[i]);
        }
    }

    function removeDevAccounts(address[] memory account) external onlyDevsOrAdmin {
        for (uint i = 0; i < account.length; i++) {
            if(!devAccounts[account[i]]) continue; // As above
            emit DevAccountRemoved(account[i]);
        }
    }

    function setCallAuthLevels(MinAuthSetting[] memory settings) external {
        // ADD CHECK FOR MULTISIG FROM PROD_TIMELOCK. ONLY PROD TIMELOCK SHOULD BE ABLE TO CHANGE AUTH LEVELS
        _setCallAuthLevels(settings);
    }

    function _setCallAuthLevels(MinAuthSetting[] memory settings) internal {
        for (uint i = 0; i < settings.length; i++) {
            bytes32 key = _getKey(settings[i].target, settings[i].funcSelector);
            minRequiredAuth[key] = settings[i].quorumId;
        }
    }

    function _getKey(address qpContract, bytes4 funcSelector) private pure returns (bytes32) {
        bytes32 key; // Takes the shape of 0x{4byteFuncSelector}00..00{20byteQPContractAddress}
        assembly {
            key := or(
                and(funcSelector, 0xffffffff00000000000000000000000000000000000000000000000000000000), // Remove this mask?
                qpContract
            )
        }
        return key;
    }

    function _validateAuthLevel(address target, bytes calldata data, address quorumId) private view {
        bytes32 key = _getKey(target, bytes4(data));
        require(uint160(quorumId) >= uint160(minRequiredAuth[key]), "Insufficient auth level");
    }
}
