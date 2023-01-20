import { ethers } from "hardhat";
import { QuantumPortalStake } from "../../../../typechain-types/QuantumPortalStake";
import { abi, deployWithOwner, deployDummyToken, getCtx, TestContext, Wei, throws } from 'foundry-contracts/dist/test/common/Utils';
import { expect } from "chai";

const DEFAULT_ID = '0x0000000000000000000000000000000000000001';

async function delpoyStake(ctx: TestContext) {
    await deployDummyToken(ctx);
    const initData = abi.encode(['address'], [ctx.token.address]);
    console.log("INIT", initData)
    const stk = await deployWithOwner(ctx, 'QuantumPortalStake', ctx.acc1, initData
        ) as QuantumPortalStake;
    return stk;
}

describe("Test qp stake", function () {
    it('One can stake, and delegate the stake', async function() {
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

    });

    it('Stake can be slashed by authority', async function() {

    });

    it('Stake stuck in the withdraw can be fully slashed', async function() {

    });

    it('Stake stuck in the withdraw can be partially slashed', async function() {

    });
});