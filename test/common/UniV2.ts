import { ChainId, Token, TokenAmount, Trade, TradeType, Route, Percent, Router, ETHER, Pair, WETH } from '@uniswap/sdk'
import { abi as IUniswapV2Router02ABI } from '@uniswap/v2-periphery/build/IUniswapV2Router02.json'
import { abi as IUniswapV2Pair} from '@uniswap/v2-core/build/IUniswapV2Pair.json'
import { ethers } from 'hardhat';
import { DummyToken } from '../../typechain/DummyToken';
import { getTransactionReceipt, Wei } from './Utils';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { Contract } from 'ethers';
import { expect } from 'chai';

export const DEFAULT_TTL = 360;
export const ROUTER_ADDRESS = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D'

function getRouterContract(signer: SignerWithAddress) {
  return new ethers.Contract(ROUTER_ADDRESS, IUniswapV2Router02ABI, signer);
}

export async function execOnRouter(contract: Contract, pars: any, from: string) {
    const { methodName, args, value } = pars;
    const res = await contract[methodName](...args, {value});
    // console.log('EXECED', res);
    const rec = await getTransactionReceipt(res.hash);
    // console.log('RECEIPT', rec);
    // const gasEstimate = await method.estimateGas({
    //     from: from,
    //     ...(value ? { value } : {})});
    // console.log('Estimated gas', gasEstimate)
    // const res = await method.send({
    //     from: from,
    //     gasLimit: new Big(gasEstimate).times('1.2').round(0).toFixed(0),
    //     ...(value ? { value } : {})});

    // const hash = res.transactionHash;
    // return await ethers.tr
}

/**
 * Note: This only works against a fork from the ethereum mainnet.
 */
export class UniV2Helper {
    private cache = {} as any;
    constructor() {
        this.registerToken(WETH[1].address, 'WETH', 'WETH');
    }

    routerContract(signer: SignerWithAddress) {
        return getRouterContract(signer);
    }

    registerToken(addr, symbol, name) {
        const token = new Token(
            ChainId.MAINNET,
            addr,
            18,
            symbol,
            name
          );
        this.cache['TOK_' + addr] = token;
    }

    // cleanPair(tok1, tok2) {
    //     const k = 'PAIR_' + this.pairAddress(tok1, tok2);
    //     this.cache.set(k, undefined);
    // }

    pairAddress(tok1: string, tok2: string) {
        return Pair.getAddress(this.tok(tok1), this.tok(tok2));
    }

    weth() {
        return WETH[1].address;
    }

    async allow(tok1: string, from: SignerWithAddress, approvee: string, amount: string) {
        const tokF = await ethers.getContractFactory('DummyToken');
        const tok = await tokF.attach(tok1) as DummyToken;
        // await tok.approve(approvee, Wei.from(amount));
        await tok.connect(from).approve(approvee, Wei.from(amount));
        const allowance = await tok.allowance(from.address, approvee);
        console.log('Allowance is ', approvee.toString(), ':', allowance.toString());
    }

    async allowRouter(tok1: string, from: SignerWithAddress) {
        return this.allow(tok1, from, ROUTER_ADDRESS, '1000000000000');
    }

    async pair(tok1: string, tok2: string) {
        const pairAddr = this.pairAddress(tok1, tok2);
        const k = 'PAIR_' + pairAddr;
        let curP = this.cache[k];
        if (!curP) {
            const contract = new ethers.Contract(pairAddr, IUniswapV2Pair);
            const res = await contract.methods.getReserves().call();
            const reserves0 = res.reserve0;
            const reserves1 = res.reserve1;
            const token1 = this.tok(tok1);
            const token2 = this.tok(tok2);
            const balances = token1.sortsBefore(token2) ? [reserves0, reserves1] : [reserves1, reserves0];
            curP = new Pair(new TokenAmount(token1, balances[0]), new TokenAmount(token2, balances[1]));
            this.cache[k] = curP;
        }
        return curP;
    }

    async route(tok1: string, tok2: string) {
        const pair = await this.pair(tok1, tok2);
        return new Route([pair], this.tok(tok1));
    }

    async price(tok1: string, tok2: string) {
        return (await this.route(tok2, tok1)).midPrice;
    }

    async buy(token: string, base: string, amount: string, slippagePct: number, to: SignerWithAddress) {
        // When we buy amount out is exact
        const t = await this.trade(base, token, 'buy', amount);
        if (base = WETH[1].address) {
            (t.inputAmount as any).currency = ETHER;
        }
        const slippageTolerance = new Percent((slippagePct * 100).toFixed(0), '10000') // in bips
        const tradeOptions = {
            allowedSlippage: slippageTolerance,
            ttl: DEFAULT_TTL,
            recipient: to.address,
        };
        const swapPars = Router.swapCallParameters(t, tradeOptions);
        return this.execOnRouter(swapPars, to);
    }

    // async sell(token, base, amount, slippagePct, to) {
    //     // When we buy amount in is exact
    //     const t = await this.trade(token, base, 'sell', amount);
    //     if (utils.isWeth(base)) {
    //         t.outputAmount.currency = ETHER;
    //     }
    //     const slippageTolerance = new Percent((slippagePct * 100).toFixed(0), '10000') // in bips
    //     const tradeOptions = {
    //         allowedSlippage: slippageTolerance,
    //         ttl: DEFAULT_TTL,
    //         recipient: to,
    //     };
    //     const swapPars = Router.swapCallParameters(t, tradeOptions);
    //     return this.execOnRouter(swapPars, to);
    // }

    async trade(tokIn: string, tokOut: string, tType: 'buy' | 'sell', amount: string) {
        const r = await this.route(tokIn, tokOut);
        const tokA = new TokenAmount(tType === 'sell' ? this.tok(tokIn) : this.tok(tokOut), Wei.from(amount));
        // console.log('TRADE', {tokIn, tokOut, tType, amount, ac: tokA.currency, rout: r.output});
        return new Trade(r, tokA, tType === 'sell' ? TradeType.EXACT_INPUT : TradeType.EXACT_OUTPUT);
    }

    // function addLiquidityETH(
    //     address token,
    //     uint amountTokenDesired,
    //     uint amountTokenMin,
    //     uint amountETHMin,
    //     address to,
    //     uint deadline
    //   ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    async addLiquidityEth(from: SignerWithAddress, token: string, tokenDesired: string, tokenMin: string, ethDesired: string, ethMin: string) {
        // Deadline for adding liquidity = now + 25 minutes
        const deadline = Date.now() + 1500;
        const pars = {
            methodName: 'addLiquidityETH',
            args: [
            token, 
            Wei.from(tokenDesired), // uint amountTokenDesired
            Wei.from(tokenMin), // uint amountTokenMin
            Wei.from(ethMin),   // uint amountETHMin
            from.address, 
            deadline, 
            ],
            value: Wei.from(ethDesired),
        }
        return await this.execOnRouter(pars, from);
    }

    async addLiquidity(
            from: SignerWithAddress,
            token: string,
            tokenDesired: string,
            tokenMin: string,
            pairToken: string,
            pairDesired: string,
            pairMin: string) {
        // Deadline for adding liquidity = now + 25 minutes
        const deadline = Date.now() + 1500;
        const pars = {
            methodName: 'addLiquidity',
            args: [
            token,
            pairToken,
            Wei.from(tokenDesired), // uint amountTokenDesired
            Wei.from(pairDesired), // uint amountTokenDesired
            Wei.from(tokenMin), // uint amountTokenMin
            Wei.from(pairMin), // uint amountTokenMin
            from.address, 
            deadline, 
            ],
        }
        return await this.execOnRouter(pars, from);
    }

    async removeLiquidity(from: SignerWithAddress, tokenA: string, tokenB: string, liquidity: string, amountAMin: string, amountBMin: string) {
        // Deadline for adding liquidity = now + 25 minutes
        const deadline = Date.now() + 1500;
        const pars = {
            methodName: 'removeLiquidity',
            args: [
            tokenA, 
            tokenB,
            Wei.to(liquidity),
            Wei.to(amountAMin),
            Wei.to(amountBMin),
            from.address, 
            deadline, 
            ],
        }
        return await this.execOnRouter(pars, from);
    }

    async removeLiquidityEth(from: SignerWithAddress, token: string, liquidity: string, amountTokenMin: string, amountETHMin: string) {
        // Deadline for adding liquidity = now + 25 minutes
        const deadline = Date.now() + 1500;
        const pars = {
            methodName: 'removeLiquidityETH',
            args: [
            token, 
            Wei.to(liquidity),
            Wei.to(amountTokenMin),
            Wei.to(amountETHMin),
            from.address, 
            deadline, 
            ],
        }
        return await this.execOnRouter(pars, from);
    }

    async execOnRouter(pars: any, from: SignerWithAddress) {
        const contract = this.routerContract(from);
        return execOnRouter(contract, pars, from.address);
    }

    tok(tokA: string) {
        const t = this.cache['TOK_'+tokA];
        if (!t) {
            throw new Error(`Token "${tokA} not registered`);
        }
        return t;
    }
}