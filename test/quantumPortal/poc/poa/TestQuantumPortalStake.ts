import { QuantumPortalStake } from "../../../../typechain-types/QuantumPortalStake";
import { getCtx, TestContext, Wei, throws } from 'foundry-contracts/dist/test/common/Utils';
import { expect } from "chai";
import { hardhatAdvanceTimeAndBlock, hardhatGetTime } from "../../../common/TimeTravel";
import { delpoyStake } from "./TestQuantumPortalStakeUtils";

async function getPendingWithdrawItems(ctx: TestContext, stk: QuantumPortalStake): Promise<{ opensAt: number, amount: string }[]> {
    const releaseQ = await stk.withdrawItemsQueueParam(ctx.owner);
    const itemsFrom = releaseQ.start.toNumber();
    const itemsTo = releaseQ.end.toNumber();
    const rv: any[] = [];
    for(let i=itemsFrom; i<itemsTo; i++) {
        const wi = await stk.withdrawItemsQueue(ctx.owner, i);
        rv.push({opensAt: wi.opensAt.toNumber(), amount: Wei.to(wi.amount.toString())});
    }
    return rv;
}

const _it: any = () => {}

describe("Test qp stake", function () {
    _it('One can stake, and delegate the stake', async function() {
        const ctx = await getCtx();
        const stk = await delpoyStake(ctx);
        const stakeId = await stk.STAKE_ID();
        await ctx.token!.transfer(stk.address, Wei.from('10'));
        await stk.stake(ctx.owner, stakeId);

        const currentStake = Wei.to((await stk.stakeOf(stakeId, ctx.owner)).toString());
        console.log('Current stake is ', currentStake);
        expect(currentStake).to.be.equal('10.0');

        await throws(stk.delegatedStakeOf(ctx.acc1), 'QPS: delegatee not valid');

        await stk.delegate(ctx.acc1);
        const delStake = Wei.to((await stk.delegatedStakeOf(ctx.acc1)).toString());
        console.log('Delegated stake: ', delStake);
        expect(delStake).to.be.equal('10.0');
    });

    it('One can withdraw, but it gets locked for a period', async function() {
        const ctx = await getCtx();
        const stk = await delpoyStake(ctx);
        const stakeId = await stk.STAKE_ID();
        await ctx.token!.transfer(stk.address, Wei.from('10'));
        await stk.stake(ctx.owner, stakeId);
        const initBalane = Wei.to((await ctx.token.balanceOf(ctx.owner)).toString());

        console.log('Now withdrawing some');
        const withdrawTime = await hardhatGetTime();
        await stk.withdraw(ctx.owner, stakeId, Wei.from('5'));
        let postWithdrawBalance = Wei.to((await ctx.token.balanceOf(ctx.owner)).toString());
        const currentStake = Wei.to((await stk.stakeOf(stakeId, ctx.owner)).toString());
        console.log('Current stake is ', currentStake);
        expect(currentStake).to.be.equal('5.0');
        console.log('Post withdraw balance', initBalane, '=>', postWithdrawBalance);

        const releaseQueue = await stk.withdrawItemsQueueParam(ctx.owner);
        console.log('Release queue: ', releaseQueue.start.toNumber(), releaseQueue.end.toNumber());
        expect(releaseQueue.start.toNumber()).to.be.equal(0);
        expect(releaseQueue.end.toNumber()).to.be.equal(1);
        const wis = await getPendingWithdrawItems(ctx, stk);
        console.log('Withdraw items: ', wis);
        expect(wis[0].opensAt).to.be.greaterThan(withdrawTime);
        expect(wis[0].amount).to.be.equal('5.0');

        const timeToPass = wis[0].opensAt - withdrawTime;
        console.log('Time before withdrawal opens', timeToPass);
        const currentTime = await hardhatGetTime();
        await hardhatAdvanceTimeAndBlock(timeToPass, 1);
        const newTime = await hardhatGetTime();
        console.log('Time increaed from ', currentTime, 'to', newTime);
        expect(newTime).to.be.greaterThanOrEqual(wis[0].opensAt, 'Time travel didnt work');

        await stk.releaseWithdrawItems(ctx.owner, ctx.owner, 0);
        console.log('Withdraw items shoulg have been released');
        const wisAferRelease = await getPendingWithdrawItems(ctx, stk);
        console.log('wisAferRelease', wisAferRelease);
        postWithdrawBalance = Wei.to((await ctx.token.balanceOf(ctx.owner)).toString());
        console.log('Post withdraw balance', initBalane, '=>', postWithdrawBalance);
        expect(Number(initBalane)+5).to.be.equal(Number(postWithdrawBalance));

        // await stk.withdraw(ctx.owner, stakeId, Wei.from('1')); // This should release the locked withdrawals
        // postWithdrawBalance = Wei.to((await ctx.token.balanceOf(ctx.owner)).toString());
        // const currentStake2 = Wei.to((await stk.stakeOf(stakeId, ctx.owner)).toString());
        // console.log('Current stake is ', currentStake2);
        // console.log('Post withdraw balance', initBalane, '=>', postWithdrawBalance);
        // const newWis = await getPendingWithdrawItems(ctx, stk);
        // console.log('Withdraw items after second withdraw: ', newWis, await hardhatGetTime());
    });

    it('Stake can be slashed by authority', async function() {

    });

    it('Stake stuck in the withdraw can be fully slashed', async function() {

    });

    it('Stake stuck in the withdraw can be partially slashed', async function() {

    });
});