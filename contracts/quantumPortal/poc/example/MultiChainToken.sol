// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../IQuantumPortalPoc.sol";
import "../IQuantumPortalFeeManager.sol";
import "foundry-contracts/contracts/common/IFerrumDeployer.sol";
import "foundry-contracts/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MultiChainToken is ERC20, Ownable {
    uint256 public immutable CHAIN_ID;
    uint256 public MASTER_CHAIN_ID = 2600; // The FRM chain ID
    uint256 public TOTAL_SUPPLY = 100000 * 10**18;
    mapping(uint256 => address) public remotes;
    IQuantumPortalPoc public portal;

    constructor() {
        uint256 overrideChainID; // for test only. provide 0 outside a test
        (name, symbol, overrideChainID) = abi.decode(IFerrumDeployer(msg.sender).initData(), (string, string, uint256));
        CHAIN_ID = overrideChainID == 0 ? block.chainid : overrideChainID;
    }

    function init(
        uint256 masterChainId,
        address quantumPortal,
        address mintTo
    ) external onlyOwner {
        require(totalSupply == 0, "Already initialized");
        MASTER_CHAIN_ID = masterChainId;
        portal = IQuantumPortalPoc(quantumPortal);
        if (CHAIN_ID == masterChainId) {
            _mint(mintTo, TOTAL_SUPPLY);
        }
    }

    function setRemote(uint256 remoteChainId, address addr) external onlyOwner {
        remotes[remoteChainId] = addr;
    }

    /**
     @notice Mints and burns.
       Note: This is not secure, becuase there is no guarantee that the burn part on a remote chain
       will go through. This is for demonstration purpose.
       TODO: Implement a two-phase commmit approach to ensure mint and burn happen atomically.
     */
    function mintAndBurn(uint64 mintChain, uint64 burnChain, uint amount, uint mintFee, uint burnFee) external {

        // Pay FRM fee. TODO: Implement
        // IQuantumPortalFeeManager feeManager = IQuantumPortalFeeManager(portal.feeManager());
        // IERC20(feeManager.feeToken()).transferFrom(msg.sender, address(feeManager), mintFee + burnFee);
        // feeManager.depositFee(address(this));

        if (mintChain == CHAIN_ID) {
            _mint(msg.sender, amount);
        } else {
            address remoteContract = remoteAddress(mintChain);
            bytes memory method = abi.encodeWithSelector(MultiChainToken.mint.selector, msg.sender, amount);
            portal.run(mintChain, remoteContract, msg.sender, method); // The fee is base fee charged on this side. Covers enough to fail the tx on the other side.
        }
        if (burnChain == CHAIN_ID) {
            _burn(msg.sender, amount);
        } else {
            address remoteContract = remoteAddress(burnChain);
            bytes memory method = abi.encodeWithSelector(MultiChainToken.burn.selector, msg.sender, amount);
            portal.run(burnChain, remoteContract, msg.sender, method);
        }
    }

    /**
     @notice We make sure this is only calle as part of a quantum portal transaction.
      As an extra security measure, you can pass in a signed message by the owner.
     */
    function mint(address to, uint amount) external {
        (uint netId, address sourceMsgSender,) = portal.msgSender();
        require(netId == MASTER_CHAIN_ID && sourceMsgSender == remoteAddress(netId), "Not allowed");
        _mint(to, amount);
    }

    /**
     @notice We make sure this is only calle as part of a quantum portal transaction.
      As an extra security measure, you can pass in a signed message by the owner.
     */
    function burn(address from, uint amount) external {
        (uint netId, address sourceMsgSender,) = portal.msgSender();
        require(netId == MASTER_CHAIN_ID && sourceMsgSender == remoteAddress(netId), "Not allowed");
        _burn(from, amount);
    }

    function remoteAddress(uint256 chainId) public view returns(address rv) {
        rv = remotes[chainId];
        rv = rv == address(0) ? address(this) : rv;
    }
}