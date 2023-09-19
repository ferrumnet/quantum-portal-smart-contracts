// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../IQuantumPortalPoc.sol";
import "../IQuantumPortalFeeManager.sol";
import "foundry-contracts/contracts/common/IFerrumDeployer.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title The example multi chain base contract that contains 
 * necessities of connecting contracts across chains 
 */
abstract contract MultiChainBase is Ownable, ReentrancyGuard {
    uint256 public CHAIN_ID;
    IQuantumPortalPoc public portal;

    constructor() {
        initialize();
    }

    /**
     * @notice Initialize the multi-chain contract. Pass data using
     * the initiData
     */
    function initialize() internal virtual {
        uint256 overrideChainID; // for test only. provide 0 outside a test
        address _portal;
        (_portal, overrideChainID) = abi.decode(
            IFerrumDeployer(msg.sender).initData(),
            (address, uint256)
        );
        portal = IQuantumPortalPoc(_portal);
        CHAIN_ID = overrideChainID == 0 ? block.chainid : overrideChainID;
    }
}

/**
 * @title The example master multi-chain contract. Inherit this contract
 *  to write your master contract in a master-slave architecture.
 */
abstract contract MultiChainMasterBase is MultiChainBase {
    mapping(uint256 => address) public remotes;

    /**
     * @notice Ensures that this method can only be called on the master chain
     */
    modifier onlyMasterChain() {
        require(CHAIN_ID == block.chainid, "MCS: Only on master chain");
        _;
    }

    /**
     * @notice Configure the remote contract that can be trusted
     * @param remoteChainId The remote chain ID
     * @param addr The remote contract
     */
    function setRemote(uint256 remoteChainId, address addr) external onlyOwner {
        remotes[remoteChainId] = addr;
    }
}

/**
 * @title The example client multi-chain contract. Inhrit this contract
 *  to write your client contract in a master-slave architecture.
 */
abstract contract MultiChainClientBase is MultiChainBase {
    address public masterContract;
    uint256 public MASTER_CHAIN_ID = 2600; // The FRM chain ID

    /**
     * @notice Sets the master chain ID
     * @param chainId The master chain ID
     */
    function setMasterChainId(uint256 chainId) external onlyOwner {
        MASTER_CHAIN_ID = chainId;
    }

    /**
     * 
     * @notice Sets the master chain contract address
     * @param _masterContract The master chain contract address
     */
    function setMasterContract(address _masterContract) external onlyOwner {
        masterContract = _masterContract;
    }
}
