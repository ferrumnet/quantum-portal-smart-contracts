import { ethers } from "hardhat";
import { expect } from "chai";
import { DummyToken } from "../../../typechain/DummyToken";
import { QuantumPortalStake } from "../../../../typechain/QuantumPortalStake";
import { randomSalt } from "../../common/Eip712Utils";
import { getBridgeMethodCall } from "../../bridge/BridgeUtilsV12";
import { QuantumPortalPoc } from "../../../typechain/QuantumPortalPoc";
import { deployAll, QuantumPortalUtils } from "./QuantumPortalUtils";
import { MultiChainStakingMaster } from "../../../typechain/MultiChainStakingMaster";
import { BigNumber, BigNumberish } from "ethers";
import {
  advanceTime,
  advanceTimeAndBlock,
  getTime,
} from "../../common/TimeTravel";

import {
  expiryInFuture,
  getCtx,
  deployUsingDeployer,
  Wei,
} from "../../common/Utils";
import { DEPLOYER_CONTRACT, DEPLPOY_SALT_1 } from "../../../scripts/consts";
import {
  TestContext,
  deployWithOwner,
  ZeroAddress,
  abi,
  throws,
} from "../../common/Utils";
const FIVE_MIN = 5 * 60 * 1000;

const _it: any = () => {};
const id1 = "0x0000000000000000000000000000000000000001";
const id2 = "0x0000000000000000000000000000000000000002";

async function deployDummyToken(
  ctx: TestContext,
  name: string = "DummyToken",
  owner: string = ZeroAddress
) {
  const abiCoder = ethers.utils.defaultAbiCoder;
  var initData = abiCoder.encode(["address"], [ctx.owner]);
  const tok = await deployWithOwner(ctx, name, owner, initData);
  if (!ctx.token) {
    ctx.token = tok;
  }
  return tok;
}
async function deployStake() {
  const ctx = await getCtx();

  let init = abi.encode(["bytes"], [ctx.owner]);

  let stake = (await deployUsingDeployer(
    "QuantumPortalStake",
    ctx.owner,
    init,
    ctx.deployer.address,
    await randomSalt()
  )) as QuantumPortalStake;
  let reward = [];
  const token = await deployDummyToken(ctx);
  await stake.initDefault(token.address);
  console.log(ZeroAddress);

  // await stake.init(token.address, "QPStake", [token.address]);
  return stake;
}

describe("Test Quantum Portal Stake", function () {
  it("QPS initDefault Also Through If double Added", async function () {
    // const stake = await deployStake();
    const ctx = await getCtx();
    await deployDummyToken(ctx);

    // const ctx = await getCtx();
    // await deployDummyToken(ctx);
    console.log("About to deploy with direct");

    const facPar = abi.encode(["address"], [ctx.token.address]);
    const qps = (await deployWithOwner(
      ctx,
      "QuantumPortalStake",
      ctx.owner,
      facPar
    )) as QuantumPortalStake;
    console.log("Stting up the default stake");
    await qps.initDefault(ctx.token.address);
    const id = ctx.token.address;

    await qps.setLockSeconds(id, 500);
    await ctx.token.transfer(qps.address, Wei.from("1"));
    await qps.stakeFor(ctx.owner, id);

    let now = BigNumber.from(await getTime());
    let withTimeOf = await qps.withdrawTimeOf(id, ctx.owner);
    console.log(`Next withdraw time: ${withTimeOf.sub(now).toString()} ${now}`);

    await advanceTimeAndBlock(200);

    await ctx.token.transfer(qps.address, Wei.from("10"));
    await qps.stakeFor(ctx.owner, id);
    now = withTimeOf;
    withTimeOf = await qps.withdrawTimeOf(id, ctx.owner);
    console.log(
      `Next withdraw time (after 10 stake): ${withTimeOf
        .sub(now)
        .toString()} [${now}]`
    );

    await advanceTimeAndBlock(200);

    await ctx.token.transfer(qps.address, Wei.from("2"));
    await qps.stakeFor(ctx.owner, id);
    now = withTimeOf;
    withTimeOf = await qps.withdrawTimeOf(id, ctx.owner);
    console.log(
      `Next withdraw time (after 10 stake): ${withTimeOf
        .sub(now)
        .toString()} [${now}]`
    );

    // await expect(qps.withdraw(ctx.owner, id, '12'), 'time stuff');
    console.log(
      `Current stake - pre: ${await Wei.toP(qps.stakeOf(id, ctx.owner))}`
    );

    const amount = await (qps.stakeOf(id, ctx.owner));

    await qps.releaseWithdrawItems(ctx.owner, ctx.owner, amount);
    await throws(qps.withdraw(ctx.owner, id2, amount), "QPS: bad id");
    await throws(
  qps.releaseWithdrawItems(ZeroAddress, ctx.owner, amount),"QPS: staker requried");

  });
});
