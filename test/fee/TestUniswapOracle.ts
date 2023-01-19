import { abi, deployDummyToken, deployUsingDeployer, getCtx, Salt, TestContext, Wei, ZeroAddress, _WETH } from "../common/Utils";
import { ethers } from "hardhat";
import { expect } from "chai";
import { advanceTimeAndBlock } from "../common/TimeTravel";
import { DummyToken } from "../../typechain-types/DummyToken";
import { UniswapOracle } from '../../typechain-types/UniswapOracle';
import { Pair, UniswapV2 } from 'foundry-contracts/dist/test/common/UniswapV2';
import { throws } from "foundry-contracts/dist/test/common/Utils";
import { BigNumber } from "ethers";

/**
 * 
 * NOTE: This test can only be run against the forked eth mainnet
 * ./bin/node.sh
 * npx hardhat test ./test/fee/TestUniswapOracle.ts --network local
 */

const USDT = '0xdac17f958d2ee523a2206206994597c13d831ec7';

const _it: any = () => { };

function bigNumX128ToHuman(x128: BigNumber): string {
    const base128 = BigNumber.from(2).pow(128);
    return x128.div(base128).toString();
}

interface UniOracleContext extends TestContext {
    pair: Pair;
    oracle: UniswapOracle;
    uniswapV2: UniswapV2;
    weth: string;
}

async function getUniOracleCtx(): Promise<UniOracleContext> {
    const ctx = await getCtx();
    const uniswapV2 = new UniswapV2(UniswapV2.ETH_ROUTER);
    await uniswapV2.init();
    const dumTok = await deployDummyToken(ctx, 'DummyToken', ZeroAddress) as DummyToken;
    ctx.token = dumTok;
    const uniV2factory = uniswapV2.factory!.address;
    console.log('Uniswap factory is: ', uniV2factory);
    const initData = abi.encode(['address'], [uniV2factory]);
    const ora = await deployUsingDeployer('UniswapOracle', ZeroAddress, initData,
        ctx.deployer.address, Salt);
    const weth = await uniswapV2.router!.WETH();
    const pair = new Pair(weth, dumTok.address);
    return {
        ...ctx,
        pair,
        oracle: ora as any,
        uniswapV2,
        weth,
    };
}

describe("Get Prices", function () {
    it('Can get price for old tokens', async function() {
        /**
         * Process:
         * - Sell some eth to buy USDT
         * - Create an ETH/USDT oracle
         * - Move time forward.
         * - Check the oracle price again
         */
        const ctx = await getUniOracleCtx();
        console.log('Buy some USDT');
        await ctx.uniswapV2.swapEthForTokens([USDT], '1', ctx.owner);
        console.log('USDT was bought form pair ', ctx.weth, USDT);
        await ctx.oracle.updatePrice([ctx.weth, USDT]);
        console.log('Prices were updated, but this is not enough to get the price yet');
        await throws(ctx.oracle.recentPriceX128([ctx.weth, USDT]), 'Array accessed at an out-of-bounds');

        advanceTimeAndBlock(2); // 2 secons later...
        console.log('Second time updating the price, but no price update.');
        await ctx.oracle.updatePrice([ctx.weth, USDT]);
        
        await throws(ctx.oracle.recentPriceX128([ctx.weth, USDT]), 'Array accessed at an out-of-bounds');

        advanceTimeAndBlock(2); // 2 secons later...
        console.log('Third time updating the price, with price update.');
        await ctx.oracle.updatePrice([ctx.weth, USDT]);

        console.log('Buy some USDT');
        await ctx.uniswapV2.swapEthForTokens([USDT], '1', ctx.owner);
        await ctx.oracle.updatePrice([ctx.weth, USDT]);

        const curPrice = await ctx.oracle.recentPriceX128([ctx.weth, USDT]);
        const usdtEthPriceMachine = bigNumX128ToHuman(curPrice);
        // Create human readable price by considering decimals (eth 18, and usdt 6)
        const usdtEthPrice = BigNumber.from(usdtEthPriceMachine).mul(1000000).div(BigNumber.from(10).pow(18 - 6)).toString();
        const ethUsdtPrice = 1/Number(usdtEthPrice) * 1000000;
        console.log('Oracle price is', curPrice.toString(), ethUsdtPrice);
        expect(ethUsdtPrice).greaterThan(10, 'ETH is too cheap!').lessThan(20000, 'ETH is too expensive!')
    });

	_it('Can get prices', async function() {
        /**
         * Process:
         * - Create a token
         * - Create a uniswap pair and add liquidity
         * - Get price (should be none)
         * - Move time forward, do a trade
         * - Get price again (should be a new price)
         * - Move time forward again. And do another trade
         * - Get price again ...
         */
        const ctx = await getUniOracleCtx();
        // await ctx.pair.token.approve(ROUTER_ADDRESS, Wei.from('999'));
        // await ctx.uniV2.addLiquidityEth(
        //     ctx.signers.owner,
        //     ctx.pair.token.address, Wei.from('100'), '0', Wei.from('10'), '0');
        // console.log('LIQ ADDED');
        
        // console.log('Liquidity added');
        // const pair = [ctx.pair.token.address, ctx.pair.weth.address];
        // await ctx.oracle.updatePrice(pair);
        // const price = await ctx.oracle.emaX128(pair, 0);
        // console.log(`What is the price ? ${price.toString()}`);
    });
});