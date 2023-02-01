import { expiryInFuture, seed0x as salt0x, Wei, ZeroAddress } from 
    'foundry-contracts/dist/test/common/Utils';
import { expect } from "chai";
import { advanceTimeAndBlock } from "../../common/TimeTravel";
import { deployAll, QuantumPortalUtils } from "./QuantumPortalUtils";

function blockMetadata(m: any): { chainId: number,  nonce: number, timestamp: number } {
    return {
        chainId: m.chainId.toNumber(),
        nonce: m.nonce.toNumber(),
        timestamp: m.timestamp.toNumber(),
    }
}

describe("Test qp", function () {
	it('Create an x-chain tx, mine and finalize!', async function() {
        const ctx = await deployAll();
        await ctx.chain1.token.transfer(ctx.chain1.poc.address, Wei.from('20'));
        await ctx.chain1.poc.runWithValue(
            Wei.from('1'),
            ctx.chain2.chainId,
            ctx.acc1,
            ZeroAddress,
            ctx.chain1.token.address,
            '0x');
        // Check the block
        let isBlockReady = await ctx.chain1.ledgerMgr.isLocalBlockReady(ctx.chain2.chainId);
        console.log('Is block ready on chain 1? ', isBlockReady);
        expect(isBlockReady).to.be.false;
        let lastNonce = await ctx.chain1.ledgerMgr.lastLocalBlock(ctx.chain2.chainId);
        console.log('Last nonce is ', lastNonce.nonce);
        let block = (await ctx.chain1.ledgerMgr.localBlockByNonce(ctx.chain2.chainId, 1))[0];
        console.log('Local block is: ', blockMetadata(block.metadata));
        let key = (await ctx.chain1.ledgerMgr.getBlockIdx(ctx.chain2.chainId, 1)).toString();
        console.log('Key is', ctx.chain2.chainId, ',', key);
        let tx = await ctx.chain1.ledgerMgr.localBlockTransactions(key, 0);
        console.log('Local block txs.0', tx);

        console.log('Moving time forward');
        await advanceTimeAndBlock(120); // Two minutes
        isBlockReady = await ctx.chain1.ledgerMgr.isLocalBlockReady(ctx.chain2.chainId);
        console.log('Is block ready on chain 1? ', isBlockReady);
        expect(isBlockReady).to.be.true;

        console.log('Now, mining a block on chain 2');
        await QuantumPortalUtils.stakeAndDelegate(ctx.chain1.stake, '1', ctx.owner, ctx.wallets[0], ctx.signers.owner);
        const txs = [{
                    token: tx.token.toString(),
                    amount: tx.amount.toString(),
                    gas: tx.gas.toString(),
                    method: tx.method.toString(),
                    remoteContract: tx.remoteContract.toString(),
                    sourceBeneficiary: tx.sourceBeneficiary.toString(),
                    sourceMsgSender: tx.sourceMsgSender.toString(),
                    timestamp: tx.timestamp.toString(),
            }];
        const [salt, expiry, signature] = await QuantumPortalUtils.generateSignatureForMining(
            ctx.chain2.ledgerMgr,
            ctx.chain1.chainId.toString(),
            '1',
            txs,
            ctx.sks[0],
        );
        await ctx.chain2.ledgerMgr.mineRemoteBlock(
            ctx.chain1.chainId,
            '1',
            txs,
            salt,
            expiry,
            signature,
        );
        console.log('Mined');
        let minedBlock = await ctx.chain2.ledgerMgr.minedBlockByNonce(ctx.chain1.chainId, 1);
        console.log('Mined block is ', JSON.stringify(minedBlock, undefined, 2));
        console.log('Now finalizing on chain2');
        await QuantumPortalUtils.callFinalizeWithSignature(
            ctx.chainId,
            ctx.chain1.chainId,
            ctx.chain2.ledgerMgr,
            ctx.chain2.autorityMgr.address,
            [ctx.wallets[0]],
            [ctx.sks[0]],
        );
        // await ctx.chain2.ledgerMgr.finalize(ctx.chain1.chainId, 1, Salt, [], salt0x(), expiryInFuture(), '0x');
        // let remoteBalance = Wei.to((await ctx.chain2.poc.remoteBalanceOf(ctx.chain1.chainId, ctx.chain1.token.address, ctx.acc1)).toString());
        let remoteBalance = Wei.to((await ctx.chain2.poc.remoteBalanceOf(ctx.chain1.chainId, ctx.chain1.token.address, tx.remoteContract.toString())).toString());
        console.log('Remote balance for acc1, token1 is', remoteBalance.toString());
        expect(remoteBalance).to.be.equal('20.0');
    });
});