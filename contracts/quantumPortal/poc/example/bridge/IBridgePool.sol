// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IBridgePool {
    function swap(
        address to,
        address token,
        uint256 targetNetwork,
        address targetToken,
        address targetAddress,
        address originToken
    ) external returns (uint256);

    function withdraw(
        address payee
    ) external returns (uint256);

    function addLiquidity(address to, address token) external;

    function removeLiquidity(
        address to,
        address token,
        uint256 amount,
        uint256 targetNetwork,
        address targetToken
    ) external;

    function removeLiquidityIfPossible(
        address to,
        address token,
        uint256 amount
    ) external;

    function liquidity(address token, address liquidityAdder)
        external
        view
        returns (uint256);
}
