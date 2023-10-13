import { abi, deployUsingDeployer, Salt, Wei, ZeroAddress } from "../../common/Utils";
import { expect } from "chai";
import { advanceTimeAndBlock } from "../../common/TimeTravel";
import { deployAll, QuantumPortalUtils } from "./QuantumPortalUtils";
import { expiryInFuture, getCtx } from "foundry-contracts/dist/test/common/Utils";
import { ethers } from "hardhat";
import { bigNumX128ToHuman, getUniOracleCtx, UniOracleContext } from "../../fee/TestUniswapUtils";
import { QuantumPortalFeeConverter } from '../../../typechain-types/QuantumPortalFeeConverter';

const _it = (a: any, b: any) => () => {};

async function createAndInitPair(ctx: UniOracleContext) {
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
    advanceTimeAndBlock(2 * 3600); 

    console.log('Now swaping some tokens');
    await ctx.uniswapV2.swapEthForTokens([ctx.pair.token.address], '0.01', ctx.owner);
    console.log('Tokens swapped');
    await ctx.oracle.updatePrice([ctx.pair.base.address, ctx.pair.token.address]);
    console.log('Updatin the price again');
    advanceTimeAndBlock(2 * 3600); // 2 secons later...

    console.log('Now swaping some tokens again');
    await ctx.uniswapV2.swapEthForTokens([ctx.pair.token.address], '0.01', ctx.owner);
    console.log('Tokens swapped, updating price for third time');
    await ctx.oracle.updatePrice([ctx.pair.base.address, ctx.pair.token.address]);
    const newPrice = await ctx.oracle.recentPriceX128([ctx.pair.base.address, ctx.pair.token.address]);
    console.log('New price is ', bigNumX128ToHuman(newPrice));
}

describe("Test fee convertor - run with forked Ethereum", function () {
	it('Creat a fee convertor over a forked chain.', async function() {
	    const ctx = await getUniOracleCtx();

        console.log('We need to create a token and liquidity.');
        await createAndInitPair(ctx);

        console.log('Deploy the fee converter');
        const initData = abi.encode(['address', 'address', 'address'], [ctx.weth, ctx.pair.token.address, ctx.oracle.address]);
        const feeC = await deployUsingDeployer('QuantumPortalFeeConverter', ZeroAddress, initData, ctx.deployer.address, Salt) as QuantumPortalFeeConverter;
        console.log('Deployed...', feeC.address);

        const price = await feeC.localChainGasTokenPriceX128();
        const priceH = bigNumX128ToHuman(price);
        console.log(`Current price is ${priceH}`);
    });
});