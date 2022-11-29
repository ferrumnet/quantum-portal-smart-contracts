// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./MultiChainBase.sol";
import "foundry-contracts/contracts/token/ERC20/ERC20.sol";

contract MitlChainToken2Master is ERC20, MultiChainMasterBase {
    uint256 public TOTAL_SUPPLY = 100000 * 10**18;

    constructor() {
    }

    function initialMint() external onlyOwner {
        require(totalSupply == 0, "Already initialized");
        _mint(msg.sender, TOTAL_SUPPLY);
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
            bytes memory method = abi.encodeWithSelector(MitlChainToken2Client.mint.selector, msg.sender, amount);
            portal.run(mintFee, mintChain, remoteContract, msg.sender, method); // The fee is base fee charged on this side. Covers enough to fail the tx on the other side.
        }
        if (burnChain == CHAIN_ID) {
            _burn(msg.sender, amount);
        } else {
            address remoteContract = remoteAddress(burnChain);
            bytes memory method = abi.encodeWithSelector(MitlChainToken2Client.burn.selector, msg.sender, amount);
            portal.run(burnFee, burnChain, remoteContract, msg.sender, method);
        }
    }

    function remoteAddress(uint256 chainId) public view returns(address rv) {
        rv = remotes[chainId];
        rv = rv == address(0) ? address(this) : rv;
    }
}

contract MitlChainToken2Client is ERC20, MultiChainClientBase {

    /**
     @notice We make sure this is only calle as part of a quantum portal transaction.
      As an extra security measure, you can pass in a signed message by the owner.
     */
    function mint(address to, uint amount) external {
        (uint netId, address sourceMsgSender,) = portal.msgSender();
        require(netId == MASTER_CHAIN_ID && sourceMsgSender == masterContract, "Not allowed");
        _mint(to, amount);
    }

    /**
     @notice We make sure this is only calle as part of a quantum portal transaction.
      As an extra security measure, you can pass in a signed message by the owner.
     */
    function burn(address from, uint amount) external {
        (uint netId, address sourceMsgSender,) = portal.msgSender();
        require(netId == MASTER_CHAIN_ID && sourceMsgSender == masterContract, "Not allowed");
        _burn(from, amount);
    }

}