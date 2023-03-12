import { abi, deployDummyToken, deployUsingDeployer, expiryInFuture, getCtx, Salt, TestContext, Wei, ZeroAddress, _WETH } from "../common/Utils";
import { expect } from "chai";
import { advanceTimeAndBlock } from "../common/TimeTravel";
import { DummyToken } from "../../typechain-types/DummyToken";
import { UniswapOracle } from '../../typechain-types/UniswapOracle';
import { Pair, UniswapV2 } from 'foundry-contracts/dist/test/common/UniswapV2';
import { throws } from "foundry-contracts/dist/test/common/Utils";
import { BigNumber } from "ethers";
import Big from 'big.js';

/**
 * 
 * NOTE: This test can only be run against the forked eth mainnet
 * ./bin/node.sh
 * npx hardhat test ./test/fee/TestUniswapOracle.ts --network local
 */

function ethCallThrows(expected: number) {
    return async (fun: Promise<any>) => {
        try {
            await fun;
        } catch (e) {
            const errCode = (e.errorArgs || [])[0];
            if (!errCode) {
                console.error('ethCallThrows', e);
                throw new Error(`Expected error code ${errCode}, but no e.errorArgs exists`);
            }
            if (!(errCode as BigNumber).toNumber) {
                console.error('ethCallThrows', e);
                throw new Error(`Expected error code ${errCode}, but the first e.errorArgs is not an error code`);
            }
            const errCodeNum = (errCode as BigNumber).toNumber();
            if (errCodeNum !== expected) {
                throw new Error(`Unexpected error code. Expected "${errCode.toString()}", but received ${errCodeNum.toString()}`)
            }
        }
    }
}

const USDT = '0xdac17f958d2ee523a2206206994597c13d831ec7';

const _it: any = () => { };

function bigNumX128ToHuman(x128: BigNumber): string {
    const base128 = new Big(2).pow(128);
    return new Big(x128.toString()).div(base128).toString();
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
        await ethCallThrows(0x32)(ctx.oracle.recentPriceX128([ctx.weth, USDT]));
        console.log('.')

        advanceTimeAndBlock(2); // 2 secons later...
        console.log('Second time updating the price, but no price update.');
        await ctx.oracle.updatePrice([ctx.weth, USDT]);
        
        await ethCallThrows(0x32)(ctx.oracle.recentPriceX128([ctx.weth, USDT]));

        advanceTimeAndBlock(2); // 2 secons later...
        console.log('Third time updating the price, with price update.');
        await ctx.oracle.updatePrice([ctx.weth, USDT]);

        console.log('Buy some USDT');
        await ctx.uniswapV2.swapEthForTokens([USDT], '1', ctx.owner);
        await ctx.oracle.updatePrice([ctx.weth, USDT]);
        console.log('Price updated');

        const curPrice = await ctx.oracle.recentPriceX128([ctx.weth, USDT]);
        const usdtEthPriceMachine = bigNumX128ToHuman(curPrice);
        // Create human readable price by considering decimals (eth 18, and usdt 6)
        const usdtEthPrice = new Big(usdtEthPriceMachine).mul(1000000).div(new Big(10).pow(18 - 6)).toString();
        const ethUsdtPrice = 1/Number(usdtEthPrice) * 1000000;
        console.log('Oracle price is', curPrice.toString(), ethUsdtPrice);
        expect(ethUsdtPrice).greaterThan(10, 'ETH is too cheap!').lessThan(20000, 'ETH is too expensive!')
    });

	it('Can get prices for new tokens', async function() {
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

        console.log('Adding liquidity to', ctx.pair.base.address, ctx.pair.token.address);
        console.log('Approve');
        await (await ctx.pair.token.token()).approve(ctx.uniswapV2.router.address, Wei.from('999999'));
        console.log('Add liq');
        await ctx.uniswapV2.router.addLiquidityETH(
            ctx.pair.token.address,
            Wei.from('10'),
            '0',
            '0',
            ctx.owner,
            expiryInFuture(), { value: Wei.from('1') }
        );
        console.log('LIQ ADDED');
        await ctx.pair.init(ctx.uniswapV2.factory!);
        const currentLiqBase = await (await ctx.pair.base.token()).balanceOf(ctx.pair.pair.address);
        const currentLiqToken = await (await ctx.pair.token.token()).balanceOf(ctx.pair.pair.address);
        console.log(`Current liquidity - Base: ${Wei.to(currentLiqBase.toString())}, Token: ${Wei.to(currentLiqToken.toString())}`);
        
        console.log('Updating the price 1st time');
        await ctx.oracle.updatePrice([ctx.pair.base.address, ctx.pair.token.address]);
        await ethCallThrows(0x32)(ctx.oracle.recentPriceX128([ctx.pair.base.address, ctx.pair.token.address]));
        advanceTimeAndBlock(2 * 3600); 

        console.log('Now swaping some tokens');
        await ctx.uniswapV2.swapEthForTokens([ctx.pair.token.address], '0.01', ctx.owner);
        console.log('Tokens swapped');
        await ctx.oracle.updatePrice([ctx.pair.base.address, ctx.pair.token.address]);
        console.log('Updatin the price again');
        await ethCallThrows(0x32)(ctx.oracle.recentPriceX128([ctx.pair.base.address, ctx.pair.token.address]));
        advanceTimeAndBlock(2 * 3600); // 2 secons later...

        console.log('Now swaping some tokens again');
        await ctx.uniswapV2.swapEthForTokens([ctx.pair.token.address], '0.01', ctx.owner);
        console.log('Tokens swapped, updating price for third time');
        await ctx.oracle.updatePrice([ctx.pair.base.address, ctx.pair.token.address]);
        const newPrice = await ctx.oracle.recentPriceX128([ctx.pair.base.address, ctx.pair.token.address]);
        console.log('New price is ', bigNumX128ToHuman(newPrice));
    });

    it('TODO: Test different EMAs', async function () {
        // We can use different EMAs
    });
});