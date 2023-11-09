// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "./IBridgePool.sol";
import "../common/uniswap/IUniswapV2Router02.sol";
import "../common/uniswap/IWETH.sol";
import "../common/IFerrumDeployer.sol";
import "../staking/remote/IRemoteStake.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../common/SafeAmount.sol";

/**
 @notice The router for bridge
 */
contract BridgeRouterV12 is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    address public pool;
    address public stake;

    constructor() {}

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
     @notice Sets the staking contract
     @param _stake The staking contract
     */
    function setStake(address _stake) external onlyOwner {
        stake = _stake;
    }

    /**
     @notice Initiate an x-chain swap.
     @param token The source token to be swaped
     @param amount The source amount
     @param targetNetwork The chain ID for the target network
     @param targetToken The target token address
     @param swapTargetTokenTo Swap the target token to a new token
     @param targetAddress Final destination on target
     */
    function swap(
        address token,
        uint256 amount,
        uint256 targetNetwork,
        address targetToken,
        address swapTargetTokenTo,
        address targetAddress
    ) external {
        IERC20(token).safeTransferFrom(msg.sender, pool, amount);
        IBridgePool(pool).swap(
            msg.sender,
            token,
            targetNetwork,
            targetToken,
            swapTargetTokenTo,
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
        IRemoteStake(stake).syncStake(to, token);
    }

    /**
     @notice Add staking rewards for a token
     @param token The token
     @param amount The reward amount
     */
    function addReward(address token, uint256 amount) external {
        IERC20(token).safeTransferFrom(msg.sender, stake, amount);
        IRemoteStake(stake).addReward(token, token);
    }

    /**
     @notice Do a local swap and generate a cross-chain swap
     @param swapRouter The local swap router
     @param amountIn The amount in
     @param amountCrossMin Equivalent to amountOutMin on uniswap
     @param path The swap path
     @param deadline The swap dealine
     @param crossTargetNetwork The target network for the swap
     @param crossSwapTargetTokenTo If different than crossTargetToken, a swap
       will also be required on the other end
     @param crossTargetAddress The target address for the swap
     */
    function swapAndCross(
        address swapRouter,
        uint256 amountIn,
        uint256 amountCrossMin, // amountOutMin on uniswap
        address[] calldata path,
        uint256 deadline,
        uint256 crossTargetNetwork,
        address crossTargetToken,
        address crossSwapTargetTokenTo,
        address crossTargetAddress
    ) external nonReentrant {
        amountIn = SafeAmount.safeTransferFrom(path[0], msg.sender, address(this), amountIn);
        approveIfRequired(path[0], swapRouter, amountIn);
        _swapAndCross(
            msg.sender,
            swapRouter,
            amountIn,
            amountCrossMin,
            path,
            deadline,
            crossTargetNetwork,
            crossTargetToken,
            crossSwapTargetTokenTo,
            crossTargetAddress
        );
    }

    /**
     @notice Do a local swap and generate a cross-chain swap
     @param swapRouter The local swap router
     @param amountCrossMin Equivalent to amountOutMin on uniswap
     @param path The swap path
     @param deadline The swap dealine
     @param crossTargetNetwork The target network for the swap
     @param crossSwapTargetTokenTo If different than crossTargetToken, a swap
       will also be required on the other end
     @param crossTargetAddress The target address for the swap
     */
    function swapAndCrossETH(
        address swapRouter,
        uint256 amountCrossMin, // amountOutMin
        address[] calldata path,
        uint256 deadline,
        uint256 crossTargetNetwork,
        address crossTargetToken,
        address crossSwapTargetTokenTo, // The target token that we will swap to on the other end
        address crossTargetAddress
    ) external payable {
        uint256 amountIn = msg.value;
        address weth = IUniswapV2Router01(swapRouter).WETH();
        approveIfRequired(weth, swapRouter, amountIn);
        IWETH(weth).deposit{value: amountIn}();
        _swapAndCross(
            msg.sender,
            swapRouter,
            amountIn,
            amountCrossMin,
            path,
            deadline,
            crossTargetNetwork,
            crossTargetToken,
            crossSwapTargetTokenTo,
            crossTargetAddress
        );
    }

    /**
     @notice Withdraws funds based on a multisig
     @dev For signature swapToToken must be the same as token
     @param token The token to withdraw
     @param payee Address for where to send the tokens to
     @param amount The mount
     @param sourceChainId The source chain initiating the tx
     @param swapTxId The txId for the swap from the source chain
     @param multiSignature The multisig validator signature
     */
    function withdrawSigned(
        address token,
        address payee,
        uint256 amount,
        uint32 sourceChainId,
        bytes32 swapTxId,
        bytes memory multiSignature
    ) external {
        IBridgePool(pool).withdrawSigned(
            token,
            payee,
            amount,
            token,
            sourceChainId,
            swapTxId,
            multiSignature
        );
    }

    /**
     @notice Withdraws funds and swaps to a new token
     @param to Address for where to send the tokens to
     @param swapRouter The swap router address
     @param amountIn The amount to swap
     @param sourceChainId The source chain Id. Used for signature
     @param swapTxId The source tx Id. Used for signature
     @param amountOutMin Same as amountOutMin on uniswap
     @param path The swap path
     @param deadline The swap deadline
     @param multiSignature The multisig validator signature
     */
    function withdrawSignedAndSwap(
        address to,
        address swapRouter,
        uint256 amountIn,
        uint32 sourceChainId,
        bytes32 swapTxId,
        uint256 amountOutMin, // amountOutMin on uniswap
        address[] calldata path,
        uint256 deadline,
        bytes memory multiSignature
    ) external {
        require(path.length > 1, "BR: path too short");
        IBridgePool(pool).withdrawSigned(
            path[0],
            address(this),
            amountIn,
            path[path.length - 1],
            sourceChainId,
            swapTxId,
            multiSignature
        );
        amountIn = IERC20(path[0]).balanceOf(address(this)); // Actual amount received
        approveIfRequired(path[0], swapRouter, amountIn);
        IUniswapV2Router02(swapRouter)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                amountIn,
                amountOutMin,
                path,
                to,
                deadline
            );
    }

    /**
     @notice Withdraws funds and swaps to a new token
     @param to Address for where to send the tokens to
     @param swapRouter The swap router address
     @param amountIn The amount to swap
     @param sourceChainId The source chain Id. Used for signature
     @param swapTxId The source tx Id. Used for signature
     @param amountOutMin Same as amountOutMin on uniswap
     @param path The swap path
     @param deadline The swap deadline
     @param multiSignature The multisig validator signature
     */
    function withdrawSignedAndSwapETH(
        address to,
        address swapRouter,
        uint256 amountIn,
        uint32 sourceChainId,
        bytes32 swapTxId,
        uint256 amountOutMin,
        address[] calldata path,
        uint256 deadline,
        bytes memory multiSignature
    ) external {
        IBridgePool(pool).withdrawSigned(
            path[0],
            address(this),
            amountIn,
            path[path.length - 1],
            sourceChainId,
            swapTxId,
            multiSignature
        );
        amountIn = IERC20(path[0]).balanceOf(address(this)); // Actual amount received
        IUniswapV2Router02(swapRouter)
            .swapExactTokensForETHSupportingFeeOnTransferTokens(
                amountIn,
                amountOutMin,
                path,
                to,
                deadline
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
        IRemoteStake(stake).withdrawRewardsFor(msg.sender, token);
        IBridgePool(pool).removeLiquidity(
            msg.sender,
            token,
            amount,
            targetNetwork,
            targetToken
        );
        IRemoteStake(stake).syncStake(msg.sender, token); 
    }

    /**
     @notice Removes liquidity but only up to the amount available
     @param token The token
     @param amount Desiered amount
     */
    function removeLiquidityIfPossible(address token, uint256 amount) external {
        require(token != address(0), "BR: token required");
        require(amount != 0, "BR: amount required");
        IRemoteStake(stake).withdrawRewardsFor(msg.sender, token);
        IBridgePool(pool).removeLiquidityIfPossible(msg.sender, token, amount);
        IRemoteStake(stake).syncStake(msg.sender, token);
    }

    /**
     @notice Runs a local swap and then a cross chain swap
     @param to The receiver
     @param swapRouter the swap router
     @param amountIn The amount in
     @param amountCrossMin Equivalent to amountOutMin on uniswap 
     @param path The swap path
     @param deadline The swap deadline
     @param crossTargetNetwork The target chain ID
     @param crossTargetToken The target network token
     @param crossSwapTargetTokenTo The target network token after swap
     @param crossTargetAddress The receiver of tokens on the target network
     */
    function _swapAndCross(
        address to,
        address swapRouter,
        uint256 amountIn,
        uint256 amountCrossMin, 
        address[] calldata path,
        uint256 deadline,
        uint256 crossTargetNetwork,
        address crossTargetToken,
        address crossSwapTargetTokenTo,
        address crossTargetAddress
    ) internal {
        IUniswapV2Router02(swapRouter)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                amountIn,
                amountCrossMin,
                path,
                pool,
                deadline
            );
        address crossToken = path[path.length - 1];
        IBridgePool(pool).swap(
            to,
            crossToken,
            crossTargetNetwork,
            crossTargetToken,
            crossSwapTargetTokenTo,
            crossTargetAddress,
            path[0]
        );
    }

    /**
     @notice Generates approval for the router if required
     @param token The token
     @param router The AMM router
     @param amount The amount
     */
    function approveIfRequired(
        address token,
        address router,
        uint256 amount
    ) internal {
        uint256 allowance = IERC20(token).allowance(address(this), router);
        if (allowance < amount) {
            if (allowance != 0) {
                IERC20(token).safeApprove(router, 0);
            }
            IERC20(token).safeApprove(router, type(uint256).max);
        }
    }
}
