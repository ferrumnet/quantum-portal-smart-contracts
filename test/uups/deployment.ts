import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { deployAll } from "./Utils";
import hre from "hardhat";
import { throws, Wei, ZeroAddress } from 'foundry-contracts/dist/test/common/Utils';
import { advanceTimeAndBlock } from "../common/TimeTravel";
import { estimateGasUsingEthCall, PortalContext, QuantumPortalUtils } from "../quantumPortal/poc/QuantumPortalUtils";

function blockMetadata(m: any): { chainId: number,  nonce: number, timestamp: number } {
    return {
        chainId: m.chainId,
        nonce: m.nonce,
        timestamp: m.timestamp,
    }
}

describe("Proxy version", function () {
    let ctx

    describe("Deployment", function () {
        beforeEach("Deploy", async function () {
            ctx = await deployAll();
        });
        
        it('Create an x-chain tx, mine and finalize!', async function () {
            const ctx = await deployAll();
            await ctx.chain1.token.transfer(ctx.chain1.poc, Wei.from('20'));
            console.log(`Calling run without fee. this should fail!`);
            await throws(ctx.chain1.poc.runWithValue(
                ctx.chain2.chainId,
                ctx.acc1,
                ZeroAddress,
                ctx.chain1.token,
                '0x'), 'QPWPS: Not enough fee');
            
            console.log("target forf ee")
            console.log(await ctx.chain1.ledgerMgr.minerMgr())
            console.log(await ctx.chain1.poc.mgr())
            // await ctx.chain1.poc.updateFeeTarget()
            const feeTarget = await ctx.chain1.poc.feeTarget();
            console.log(`Fee target is ${feeTarget}`);
            let feeAmount = await ctx.chain1.feeConverter.targetChainFixedFee(ctx.chain2.chainId, QuantumPortalUtils.FIXED_FEE_SIZE + 0 /* No method call*/)
            feeAmount = feeAmount + 10000000000000n // plus some var fee
            await ctx.chain1.token.transfer(feeTarget, feeAmount);
            console.log(`Sent fee to ${feeTarget} - Worth ${feeAmount}. Now we can register the tx`);
            await ctx.chain1.poc.runWithValue(
                ctx.chain2.chainId,
                ctx.acc1,
                ZeroAddress,
                ctx.chain1.token,
                '0x');
            // Check the block
            let lastLocalBlock = await ctx.chain1.state.getLastLocalBlock(ctx.chain2.chainId);
            expect(lastLocalBlock.nonce).to.be.equal(1, 'Unexpected nonce!');

            console.log('Is the fee collected?');
            let collectedFixedFee = await ctx.chain1.minerMgr.collectedFixedFee(ctx.chain2.chainId);
            let collectedVarFee = await ctx.chain1.minerMgr.collectedVarFee(ctx.chain2.chainId);
            console.log(`Fee collected: Fixed: ${collectedFixedFee} - Var: ${collectedVarFee}`);
            expect(collectedFixedFee.toString()).to.be.equal('288000000000000000');
            expect(collectedVarFee.toString()).to.be.equal('10000000000000');

            let isBlockReady = await ctx.chain1.ledgerMgr.isLocalBlockReady(ctx.chain2.chainId);
            console.log('Is block ready on chain 1? ', isBlockReady);
            expect(isBlockReady).to.be.false;
            let lastNonce = await ctx.chain1.state.getLastLocalBlock(ctx.chain2.chainId);
            console.log('Last nonce is ', lastNonce.nonce);
            let block = (await ctx.chain1.ledgerMgr.localBlockByNonce(ctx.chain2.chainId, 1))[0];
            console.log('Local block is: ', blockMetadata(block.metadata));
            let key = (await ctx.chain1.ledgerMgr.getBlockIdx(ctx.chain2.chainId, 1)).toString();
            console.log('Key is', ctx.chain2.chainId, ',', key);
            let tx = await ctx.chain1.state.getLocalBlockTransaction(key, 0);
            console.log('Local block txs.0', tx);

            console.log('Moving time forward');
            await advanceTimeAndBlock(120); // Two minutes
            isBlockReady = await ctx.chain1.ledgerMgr.isLocalBlockReady(ctx.chain2.chainId);
            console.log('Is block ready on chain 1? ', isBlockReady);
            expect(isBlockReady).to.be.true;

            console.log('Now, mining a block on chain 2');
            await QuantumPortalUtils.stakeAndDelegate(ctx.chain2.ledgerMgr, ctx.chain2.stake, '10', ctx.owner, ctx.wallets[0], ctx.signers.owner, ctx.sks[0]);
            console.log('- Staked and delegated....');
            
            console.log('WIP')
            // .... Add remaining unit test from /test/quantumPortal/poc/TestQuantumPortalBasics.ts
        });
    });
});
