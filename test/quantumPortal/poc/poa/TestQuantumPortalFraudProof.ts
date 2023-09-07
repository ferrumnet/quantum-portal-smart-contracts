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

        await dumCtx.dummy1.callOnRemote(ctx.chain2.chainId, dumCtx.dummy2.address, ctx.acc2, ctx.chain1.token.address, Wei.from('0'));
        QuantumPortalUtils.mineAndFinilizeOneToTwo(ctx, 1);
        await dumCtx.dummy1.callOnRemote(ctx.chain2.chainId, dumCtx.dummy2.address, ctx.acc2, ctx.chain1.token.address, Wei.from('1'));
        console.log('Balance should have been reduced by 1');
        QuantumPortalUtils.mineAndFinilizeOneToTwo(ctx, 2, true);

        console.log('We just fialized an invalid block. We should be refunded the 1 as remote balance');
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