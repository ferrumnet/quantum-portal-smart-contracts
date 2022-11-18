// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../IQuantumPortalPoc.sol";
import "../IQuantumPortalFeeManager.sol";
import "foundary-contracts/contracts/common/IFerrumDeployer.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

abstract contract MultiChainBase is Ownable, ReentrancyGuard {
    uint256 public CHAIN_ID;
    IQuantumPortalPoc public portal;

    constructor() {
        initialize();
    }

    function initialize() internal virtual {
        uint256 overrideChainID; // for test only. provide 0 outside a test
        address _portal;
        (_portal, overrideChainID) = abi.decode(IFerrumDeployer(msg.sender).initData(), (address, uint256));
        portal = IQuantumPortalPoc(_portal);
        CHAIN_ID = overrideChainID == 0 ? block.chainid : overrideChainID;
    }
}

abstract contract MultiChainMasterBase is MultiChainBase {
    mapping (uint256 => address) public remotes;

    modifier onlyMasterChain() {
        require(CHAIN_ID == block.chainid, "MCS: Only on master chain");
        _;
    }

    function setRemote(uint256 remoteChainId, address addr) external onlyOwner {
        remotes[remoteChainId] = addr;
    }
}

abstract contract MultiChainClientBase is MultiChainBase {
    address public masterContract;
    uint256 public MASTER_CHAIN_ID = 2600; // The FRM chain ID

    function setMasterChainId(uint256 chainId) external onlyOwner {
        MASTER_CHAIN_ID = chainId;
    }

    function setMasterContract(address _masterContract) external onlyOwner {
        masterContract = _masterContract;
    }
}

