import { expect } from "chai";
import { ethers } from "hardhat";
import {
  abi,
  deploy,
  deployDummyToken,
  deployWithOwner,
  getCtx,
  getGasLimit,
  throws,
  validateBalances,
  Wei,
  ZeroAddress,
} from "../../common/Utils";
import { StakeOpen } from "../../typechain/StakeOpen";
import { BigNumber, BigNumberish } from "ethers";
import {
  advanceTime,
  advanceTimeAndBlock,
  getTime,
} from "../../common/TimeTravel";

/*
Scanario:
- deploy a few tokens
- set a bunch as tax target with different ratio
- distribute a bunch and check results

proper test?
- run thousands, and average.
*/
const FIVE_MIN = 5 * 60 * 1000;

const _it: any = () => {};

describe("TestStakeOpen", function () {
  _it("Can create a default stake, stake and unstake", async function () {
    const ctx = await getCtx();
    await deployDummyToken(ctx);
    console.log("About to deploy with direct");

    const facPar = abi.encode(["address"], [ctx.token.address]);
    const so = (await deployWithOwner(
      ctx,
      "StakeOpen",
      ctx.owner,
      facPar
    )) as StakeOpen;
    console.log("Stting up the default stake");
    await so.initDefault(ctx.token.address);

    const id = ctx.token.address;

    const baseToken = await so.baseToken(ctx.token.address);
    console.log(`Base token is ${baseToken}`);

    const staking = await so.stakings(id);
    console.log("Staking is", staking);

    console.log(
      `My stake is ${Wei.to(
        (await so.stakeOf(id, ctx.owner)).toString()
      )} out of ${Wei.to((await so.stakedBalance(id)).toString())}`
    );

    console.log("Staking zero");
    await throws(so.stake(ctx.owner, id), "amount is required");
    console.log("Staking zero completed");

    await ctx.token.transfer(so.address, Wei.from("1"));
    console.log("Staking 1");
    await so.stake(ctx.owner, id);
    console.log("Staking 1 completed");

    console.log(
      `My stake is ${Wei.to(
        (await so.stakeOf(id, ctx.owner)).toString()
      )} out of ${Wei.to((await so.stakedBalance(id)).toString())}`
    );

    /*
		More scenarios here:
		- add reward
		- check reward
		- take reward
		- add more reward
		- withdraw partial
		- check rew and stake and bal
		- withdraw the remaining
		- check rew and stake and bal
		*/

    await ctx.token.transfer(so.address, Wei.from("1"));
    await so.addMarginalReward(ctx.token.address);
    console.log(
      `My reward is ${Wei.to(
        (await so.rewardOf(id, ctx.owner, [ctx.token.address])).toString()
      )}}`
    );

    await ctx.token.transfer(ctx.acc1, Wei.from("5"));
    await ctx.token.transfer(so.address, Wei.from("1"));
    await so.stake(ctx.acc1, id);
    console.log(
      `ACC1: Fake reward ${await so.fakeRewardOf(
        id,
        ctx.acc1,
        ctx.token.address
      )}`
    );
    console.log(
      `ACC1: My stake is ${Wei.to(
        (await so.stakeOf(id, ctx.acc1)).toString()
      )} out of ${Wei.to((await so.stakedBalance(id)).toString())}`
    );
    console.log(
      `ACC1: My reward is ${(
        await so.rewardOf(id, ctx.acc1, [ctx.token.address])
      ).toString()}}`
    );

    await ctx.token.transfer(so.address, Wei.from("1"));
    await so.addMarginalReward(ctx.token.address);
    console.log(
      `My reward is ${Wei.to(
        (await so.rewardOf(id, ctx.owner, [ctx.token.address])).toString()
      )}}`
    );
    console.log(
      `ACC1: My reward is ${Wei.to(
        (await so.rewardOf(id, ctx.acc1, [ctx.token.address])).toString()
      )}}`
    );

    console.log(`Bal pre: ${await Wei.bal(ctx.token, ctx.owner)}`);
    await so.withdrawRewards(ctx.owner, id);
    console.log(`Bal post: ${await Wei.bal(ctx.token, ctx.owner)}`);
    console.log(`Stake post: ${await Wei.toP(so.stakeOf(id, ctx.owner))}`);
    console.log(
      `Rew post: ${await Wei.toP(
        so.rewardOf(id, ctx.owner, [ctx.token.address])
      )}`
    );

    console.log(`ACC1: Bal pre: ${await Wei.bal(ctx.token, ctx.acc1)}`);
    console.log(
      `Next unstake time: ${await so.withdrawTimeOf(
        id,
        ctx.acc1
      )} vs ${Math.round(Date.now() / 1000)} `
    );
    console.log(`ACC1: Stake pre: ${await Wei.toP(so.stakeOf(id, ctx.acc1))}`);
    console.log(
      `ACC1: Rew pre: ${await Wei.toP(
        so.rewardOf(id, ctx.acc1, [ctx.token.address])
      )}`
    );
    await so.connect(ctx.signers.acc1).withdraw(ctx.acc1, id, Wei.from("0.5"));
    console.log(`ACC1: Bal post: ${await Wei.bal(ctx.token, ctx.acc1)}`);
    console.log(`ACC1: Stake post: ${await Wei.toP(so.stakeOf(id, ctx.acc1))}`);
    console.log(
      `ACC1: Rew post: ${await Wei.toP(
        so.rewardOf(id, ctx.acc1, [ctx.token.address])
      )}`
    );
    await so.connect(ctx.signers.acc1).withdraw(ctx.acc1, id, Wei.from("0.5"));
    console.log(`ACC1: 2=Bal post: ${await Wei.bal(ctx.token, ctx.acc1)}`);
    console.log(
      `ACC1: 2=Stake post: ${await Wei.toP(so.stakeOf(id, ctx.acc1))}`
    );
    console.log(
      `ACC1: 2=Rew post: ${await Wei.toP(
        so.rewardOf(id, ctx.acc1, [ctx.token.address])
      )}`
    );
  });
  _it(
    "Run many stake, and unstake, and add / remoce rewards. At the end withdraw all and ensure all rewards are zero",
    async function () {}
  );
  _it("Test withdraw lock", async () => {
    const ctx = await getCtx();
    await deployDummyToken(ctx);
    console.log("About to deploy with direct");

    const facPar = abi.encode(["address"], [ctx.token.address]);
    const so = (await deployWithOwner(
      ctx,
      "StakeOpen",
      ctx.owner,
      facPar
    )) as StakeOpen;
    console.log("Stting up the default stake");
    await so.initDefault(ctx.token.address);
    const id = ctx.token.address;

    await so.setLockSeconds(id, 500);
    await ctx.token.transfer(so.address, Wei.from("1"));
    await so.stakeFor(ctx.owner, id);

    let now = BigNumber.from(await getTime());
    let withTimeOf = await so.withdrawTimeOf(id, ctx.owner);
    console.log(`Next withdraw time: ${withTimeOf.sub(now).toString()} ${now}`);

    await advanceTimeAndBlock(200);

    await ctx.token.transfer(so.address, Wei.from("10"));
    await so.stakeFor(ctx.owner, id);
    now = withTimeOf;
    withTimeOf = await so.withdrawTimeOf(id, ctx.owner);
    console.log(
      `Next withdraw time (after 10 stake): ${withTimeOf
        .sub(now)
        .toString()} [${now}]`
    );

    await advanceTimeAndBlock(200);

    await ctx.token.transfer(so.address, Wei.from("2"));
    await so.stakeFor(ctx.owner, id);
    now = withTimeOf;
    withTimeOf = await so.withdrawTimeOf(id, ctx.owner);
    console.log(
      `Next withdraw time (after 10 stake): ${withTimeOf
        .sub(now)
        .toString()} [${now}]`
    );

    // await expect(so.withdraw(ctx.owner, id, '12'), 'time stuff');
    console.log(
      `Current stake - pre: ${await Wei.toP(so.stakeOf(id, ctx.owner))}`
    );
    await throws(
      so.withdraw(ctx.owner, id, Wei.from("12")),
      "too early to withdraw"
    );

    await advanceTimeAndBlock(1000);
    console.log("Now withdraw most of stuff. Then we should be able to ");
    now = await so.withdrawTimeOf(id, ctx.owner);
    await so.withdraw(ctx.owner, id, Wei.from("12.9"));
    console.log(
      `Current stake - post: ${await Wei.toP(so.stakeOf(id, ctx.owner))}`
    );
    withTimeOf = await so.withdrawTimeOf(id, ctx.owner);
    console.log(
      `Next withdraw time (after withdraws): ${withTimeOf
        .sub(now)
        .toString()} [${now}]`
    );

    console.log("Now stake some more and see time time diff advancing quicker");
    await ctx.token.transfer(so.address, Wei.from("1"));
    await so.stakeFor(ctx.owner, id);
    now = withTimeOf;
    withTimeOf = await so.withdrawTimeOf(id, ctx.owner);
    console.log(
      `Next withdraw time (after 1 stake): ${withTimeOf
        .sub(now)
        .toString()} [${now}]`
    );
  })
});
