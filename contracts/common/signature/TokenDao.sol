// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "./IDaoCallable.sol";
import "./MultiSigProofOfStake.sol";
import "../../staking/interfaces/ISlashableStake.sol";

contract TokenDao is MultiSigProofOfStake {
    string public constant NAME = "TOKEN_DAO";
    string public constant VERSION = "001.000";
    uint64 constant public GOVERNANCE_GROUP_ID = 88;
    uint256 mintGovThreshold = 33;
    uint256 slashStakeThreshold = 50;
    address public token;

    event TokenSet(address indexed token);
    event SlashStakeThresholdSet(uint256 stakeThresholdValue);
    event MintGovThresholdSet(uint256 govtThresholdValue);

    constructor() EIP712(NAME, VERSION) {}

    /**
     @notice Allow owner to change the token owner in case something goes wrong.
         After the trial period, this method can be frozen so it cannot be called
         anymore.
     @param newOwner The new owner
     */
    function changeTokenOwner(address newOwner) external onlyOwner freezable {
        Ownable(token).transferOwnership(newOwner);
    }

    /**
     @notice Sets mint governance threshold. Setting this to zero effectively disables stake
         based governance.
         After the trial period, this method can be frozen so it cannot be called
         anymore.
     @param thr The threshold
     */
    function setMintGovThreshold(uint256 thr) external onlyOwner freezable {
        mintGovThreshold = thr;
        emit MintGovThresholdSet(mintGovThreshold);
    }

    /**
     @notice Sets the slash stake threshold
         After the trial period, this method can be frozen so it cannot be called
         anymore.
     @param thr The threshold
     */
    function setSlashStakeThreshold(uint256 thr) external onlyOwner freezable {
        require(thr > 0, "TD: thr required");
        slashStakeThreshold = thr;
        emit SlashStakeThresholdSet(slashStakeThreshold);
    }

    /**
     @notice Sets the token. Only by owner
     @param _token The token
     */
    function setToken(address _token) external onlyOwner freezable {
        require(_token != address(0), "TD: _token requried");
        token = _token;
        // event for keeping track of the new token
        emit TokenSet(token);
    }

    bytes32 constant DO_ACTION_METHOD_CALL =
        keccak256(
            "DoAction(bytes32 action,bytes parameters,bytes32 salt,uint64 expiry)"
        );
    /**
     @notice Calls an action on the token that is controlled by dao
     @param action The hash of the action message
     @param parameters The list of parameters
     @param salt The salt
     @param expiry The expiry timeout
     @param multiSignature The encodedd multisignature
     */
    function doAction(
        bytes32 action,
        bytes calldata parameters,
        bytes32 salt,
        uint64 expiry,
        bytes calldata multiSignature
        ) external onlyAdmin expiryRange(expiry) {
        bytes32 message = keccak256(
            abi.encode(
                DO_ACTION_METHOD_CALL,
                action,
                parameters,
                salt,
                expiry
            )
        );
        verifyWithThreshold(
            message,
            salt,
            mintGovThreshold,
            GOVERNANCE_GROUP_ID,
            multiSignature
        );
        IDaoCallable(token).daoAction(action, parameters);
    }

    bytes32 constant MINT_SIGNED_METHOD =
        keccak256(
            "Mint(uint256 amount,address to,bytes32 salt,uint64 expiry)"
        );
    bytes32 constant TOKEN_MINT_METHOD =
        keccak256(
            "Mint(uint256 amount,address to)"
        );
    /**
     @notice Mints more token. This should be signed by the governance, but
         only called by admin as a veto
     */
    function mint(
        uint256 amount,
        address to,
        bytes32 salt,
        uint64 expiry,
        bytes calldata multiSignature
        ) external onlyAdmin expiryRange(expiry) {
        bytes32 message = keccak256(
            abi.encode(
                MINT_SIGNED_METHOD,
                amount,
                to,
                salt,
                expiry
            )
        );
        verifyWithThreshold(
            message,
            salt,
            mintGovThreshold,
            GOVERNANCE_GROUP_ID,
            multiSignature
        );
        IDaoCallable(token).daoAction(TOKEN_MINT_METHOD, abi.encode(to, amount));
    }

    bytes32 constant SLASH_STAKE_SIGNED_METHOD =
        keccak256(
            "SlashStake(address staker,uint256 amount,bytes32 salt,uint64 expiry)"
        );
    /**
     @notice Slashes someone stake
         only called by admin as a veto
     */
    function slashStake(
        address staker,
        uint256 amount,
        bytes32 salt,
        uint64 expiry,
        bytes calldata multiSignature
        ) external onlyAdmin expiryRange(expiry) {
        bytes32 message = keccak256(
            abi.encode(
                SLASH_STAKE_SIGNED_METHOD,
                staker,
                amount,
                salt,
                expiry
            )
        );
        verifyWithThreshold(
            message,
            salt,
            slashStakeThreshold,
            GOVERNANCE_GROUP_ID,
            multiSignature
        );
        ISlashableStake(staking).slash(stakedToken, staker, amount);
    }

    bytes32 constant UPGRADE_DAO =
        keccak256(
            "UpgradeDao(address newDao,bytes32 salt,uint64 expiry)"
        );
    /**
     @notice Slashes someone stake
         only called by admin as a veto
     */
    function upgradeDao(
        address newDao,
        bytes32 salt,
        uint64 expiry,
        bytes calldata multiSignature
        ) external onlyAdmin expiryRange(expiry) {
        bytes32 message = keccak256(
            abi.encode(
                UPGRADE_DAO,
                newDao,
                salt,
                expiry
            )
        );
        verifyWithThreshold(
            message,
            salt,
            mintGovThreshold,
            GOVERNANCE_GROUP_ID,
            multiSignature
        );
        Ownable(token).transferOwnership(newDao);
    }
}