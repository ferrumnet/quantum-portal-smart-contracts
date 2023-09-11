import { expect } from "chai";
import { PortalContext, QuantumPortalUtils, deployAll } from "../QuantumPortalUtils";
import { DummyMultiChainApp } from '../../../../typechain-types/DummyMultiChainApp';
import { ethers } from "hardhat";
import { Wei } from "foundry-contracts/dist/test/common/Utils";

interface DummyContext {
    dummy1: DummyMultiChainApp;
    dummy2: DummyMultiChainApp;
}

async function deployDummies(ctx: PortalContext): Promise<DummyContext> {
    const dummyF = await ethers.getContractFactory('DummyMultiChainApp');
    const dummy1 = await dummyF.deploy(ctx.chain1.poc.address, ctx.chain1.ledgerMgr.address, ctx.chain1.token.address) as DummyMultiChainApp;
    const dummy2 = await dummyF.deploy(ctx.chain2.poc.address, ctx.chain2.ledgerMgr.address, ctx.chain2.token.address) as DummyMultiChainApp;
    await ctx.chain1.token.transfer(dummy1.address, Wei.from('100'));
    await ctx.chain2.token.transfer(dummy2.address, Wei.from('100'));
    return {
        dummy1, dummy2
    }
}

describe("Test fraud proofs", function () {
	it('finalizer can mark some blocks as invalid, and they will get refunded - simple', async function() {
        // create one tx and one block
        // mine the block
        // finalize the block as invalid.
        // make sure we are refunded
        const ctx = await deployAll();
        const dumCtx = await deployDummies(ctx);

        let contractBal = await ctx.chain1.token.balanceOf(dumCtx.dummy1.address);
        console.log('1st: Current Tok balance for dummy1 ', contractBal.toString());
        await dumCtx.dummy1.callOnRemote(ctx.chain2.chainId, dumCtx.dummy2.address, ctx.acc2, ctx.chain1.token.address, Wei.from('0'));
        console.log('dumCtx.dummy1.callOnRemote...');
        await QuantumPortalUtils.mineAndFinilizeOneToTwo(ctx, 1);
        console.log('Min and fin finished...');

        await dumCtx.dummy1.callOnRemote(ctx.chain2.chainId, dumCtx.dummy2.address, ctx.acc2, ctx.chain1.token.address, Wei.from('1'));
        contractBal = await ctx.chain1.token.balanceOf(dumCtx.dummy1.address);
        // expect(contractBal).to.be.equal('98415999999999585222');
        console.log('2nd: Current Tok balance for dummy1 ', contractBal.toString());
        console.log('Balance should have been reduced by 1');
        let bal = await ctx.chain2.poc.remoteBalanceOf(ctx.chain1.chainId, ctx.chain1.token.address, ctx.acc2);
        console.log('Remote balance is: ', bal.toString());
        await QuantumPortalUtils.mineAndFinilizeOneToTwo(ctx, 2, true);

        console.log('We just fialized an invalid block. We should be refunded the 1 as remote balance');
        bal = await ctx.chain2.poc.remoteBalanceOf(ctx.chain1.chainId, ctx.chain1.token.address, ctx.acc2);
        console.log('Remote balance is: ', bal.toString());
        expect(bal.toString()).to.be.equal('1000000000000000000');
    });

	it('finalizer can mark some blocks as invalid, and they will get refunded - advanced middle failed', async function() {
        // create five txs and three blocks
        // middle one invalid
        // finalize invalid block
        // make sure we are refunded, and the others have gone through
    });

	it('finalizer can mark some blocks as invalid, and they will get refunded - advanced last failed', async function() {
        // create five txs and three blocks
        // last one invalid
        // finalize invalid block
        // make sure we are refunded, and the others have gone through
    });
});