import { abi, deployDummyToken, deployUsingDeployer, getCtx, Salt, TestContext, ZeroAddress } from "foundry-contracts/dist/test/common/Utils";
import { DummyToken } from "../../typechain-types/DummyToken";
import { UniswapOracle } from '../../typechain-types/UniswapOracle';
import { Pair, UniswapV2 } from 'foundry-contracts/dist/test/common/UniswapV2';
import { BigNumber } from "ethers";
import Big from 'big.js';

export interface UniOracleContext extends TestContext {
    pair: Pair;
    oracle: UniswapOracle;
    uniswapV2: UniswapV2;
    weth: string;
}

export function bigNumX128ToHuman(x128: BigNumber): string {
    const base128 = new Big(2).pow(128);
    return new Big(x128.toString()).div(base128).toString();
}

export async function getUniOracleCtx(): Promise<UniOracleContext> {
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

