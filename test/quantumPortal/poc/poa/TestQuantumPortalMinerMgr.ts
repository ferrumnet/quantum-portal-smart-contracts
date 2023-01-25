import { ethers } from "hardhat";
import { QuantumPortalStake } from "../../../../typechain-types/QuantumPortalStake";
import { QuantumPortalMinerMgr } from "../../../../typechain-types/QuantumPortalMinerMgr";
import { abi, deployWithOwner, deployDummyToken, getCtx, TestContext, Wei, throws, ZeroAddress, expiryInFuture } from 'foundry-contracts/dist/test/common/Utils';
import { getBridgeMethodCall, randomSalt } from "foundry-contracts/dist/test/common/Eip712Utils";
import { hardhatGetTime } from "../../../common/TimeTravel";
import { delpoyStake } from "./TestQuantumPortalStakeUtils";
import { expect } from "chai";

async function  deployMiner(ctx: TestContext, stk: QuantumPortalStake) {
    const initData = abi.encode(['address'], [stk.address]);
    console.log("INIT", initData)
    const min = await deployWithOwner(ctx, 'QuantumPortalMinerMgr', ZeroAddress, initData
        ) as QuantumPortalMinerMgr;
    return min;
}

describe('Test QP miner to see if it validates properly', function() {
    it('Can verify when miners have stake', async function() {
        const ctx = await getCtx();
        const stk = await delpoyStake(ctx);
        const mine = await deployMiner(ctx, stk);

        const msgHash = randomSalt(); // Verifying some random message
        const expiry = expiryInFuture().toString();
        const salt = randomSalt();
        // Verify with a miner that has no stakes
        const multiSig = await getBridgeMethodCall(
            await mine.NAME(),
            await mine.VERSION(),
            ctx.chainId,
            mine.address,
            'MinerSignature',
            [
                { type: 'bytes32', name: 'msgHash', value: msgHash},
                { type: 'uint64', name: 'expiry', value: expiry},
                { type: 'bytes32', name: 'salt', value: salt},
            ],
            [ctx.sks[1]]
        );
        await throws(mine.verifyMinerSignature(msgHash, expiry, salt, multiSig.signature!, 0, 1), "QPS: delegatee not valid");

        console.log('Now stake some');
        await ctx.token!.transfer(stk.address, Wei.from('2'));
        await stk.stake(ctx.owner, await stk.STAKE_ID());
        await stk.delegate(ctx.wallets[1]);
        const delegates = await stk.delegatedStakeOf(ctx.wallets[1]);
        console.log('Delegated some to ', ctx.acc1, Wei.to(delegates.toString()));
        let result = await mine.verifyMinerSignature(msgHash, expiry, salt, multiSig.signature!, 0, Wei.from('1'));
        console.log('We have enough stake, so the result is ', result.toString());
        expect(result.toString()).to.be.equal('1');

        result = await mine.verifyMinerSignature(msgHash, expiry, salt, multiSig.signature!, 0, Wei.from('3'));
        console.log('Result is ok', result);
        expect(result.toString()).to.be.equal('2');
    });
})