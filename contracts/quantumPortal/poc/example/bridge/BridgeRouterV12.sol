// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IBridgePool.sol";
import "foundry-contracts/contracts/common/IFerrumDeployer.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../../utils/WithQp.sol";
import "foundry-contracts/contracts/common/SafeAmount.sol";

/**
 @notice The router for bridge
 */
contract BridgeRouterV12 is Ownable, ReentrancyGuard, WithQp {
    using SafeERC20 for IERC20;
    address public pool;
    address public stake;

    constructor() Ownable(msg.sender) {}

    /**
     @notice The payable receive method
     */
    receive() external payable {
    }

    /**
     @notice Sets the bridge pool contract.
     @param _pool The bridge pool
     */
    function setPool(address _pool) external onlyOwner {
        pool = _pool;
    }

    /**
     @notice Initiate an x-chain swap.
     @param token The source token to be swaped
     @param amount The source amount
     @param targetNetwork The chain ID for the target network
     @param targetToken The target token address
     @param targetAddress Final destination on target
     */
    function swap(
        address token,
        uint256 amount,
        uint256 targetNetwork,
        address targetToken,
        address targetAddress,
        uint256 multiChainFee
    ) external {
        // Pay thie multi-chain fee
        address feeToken = portal.feeToken();
        IERC20(feeToken).safeTransfer(portal.feeTarget(), multiChainFee);

        IERC20(token).safeTransferFrom(msg.sender, pool, amount);
        IBridgePool(pool).swap(
            msg.sender,
            token,
            targetNetwork,
            targetToken,
            targetAddress,
            token
        );
    }

    /**
     @notice Adds liquidity for a user
     @param to Addres to add liquidity to
     @param token The token to add liquidity to
     @param amount The amount for liquidity
     */
    function addLiquidity(
        address to,
        address token,
        uint256 amount
    ) external {
        IERC20(token).safeTransferFrom(msg.sender, pool, amount);
        IBridgePool(pool).addLiquidity(to, token);
        // IRemoteStake(stake).syncStake(to, token);
    }

    /**
     @notice Withdraws funds 
     */
    function withdraw(
        address payee
    ) external {
        IBridgePool(pool).withdraw(
            payee
        );
    }

    /**
     @notice Remove liquidity and generate a withdrawal item if not enough
        liquidity was available
     @param token The token
     @param amount The amount
     @param targetNetwork The target network
     @param targetToken The target token
     */
    function removeLiquidity(
        address token,
        uint256 amount,
        uint256 targetNetwork,
        address targetToken
    ) external {
        require(token != address(0), "BR: token required");
        require(amount != 0, "BR: amount required");
        require(targetNetwork != 0, "BR: targetNetwork required");
        require(targetToken != address(0), "BR: targetToken required");
        // IRemoteStake(stake).withdrawRewardsFor(msg.sender, token);
        IBridgePool(pool).removeLiquidity(
            msg.sender,
            token,
            amount,
            targetNetwork,
            targetToken
        );
        // IRemoteStake(stake).syncStake(msg.sender, token); 
    }

    /**
     @notice Removes liquidity but only up to the amount available
     @param token The token
     @param amount Desiered amount
     */
    function removeLiquidityIfPossible(address token, uint256 amount) external {
        require(token != address(0), "BR: token required");
        require(amount != 0, "BR: amount required");
        // IRemoteStake(stake).withdrawRewardsFor(msg.sender, token);
        IBridgePool(pool).removeLiquidityIfPossible(msg.sender, token, amount);
        // IRemoteStake(stake).syncStake(msg.sender, token);
    }
}
