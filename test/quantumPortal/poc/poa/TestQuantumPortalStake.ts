import { ethers } from "hardhat";
import { expect } from "chai";
import { DummyToken } from "../../../../typechain/DummyToken";
import { QuantumPortalStake } from "../../../../typechain/QuantumPortalStake";
import { randomSalt } from "../../../common/Eip712Utils";
import { getBridgeMethodCall } from "../../../bridge/BridgeUtilsV12";
import { QuantumPortalPoc } from "../../../../typechain/QuantumPortalPoc";
import { deployAll, QuantumPortalUtils } from "../QuantumPortalUtils";
import { MultiChainStakingMaster } from "../../../../typechain/MultiChainStakingMaster";
import { BigNumber, BigNumberish } from "ethers";
import {
  advanceTime,
  advanceTimeAndBlock,
  getTime,
} from "../../../common/TimeTravel";

import {
  expiryInFuture,
  getCtx,
  deployUsingDeployer,
  Wei,
  deployDummyToken,
} from "../../../common/Utils";
import { DEPLOYER_CONTRACT, DEPLPOY_SALT_1 } from "../../../../scripts/consts";
import {
  TestContext,
  deployWithOwner,
  ZeroAddress,
  abi,
  throws,
} from "../../../common/Utils";
const FIVE_MIN = 5 * 60 * 1000;

const _it: any = () => {};
const id1 = "0x0000000000000000000000000000000000000001";
const id2 = "0x0000000000000000000000000000000000000002";

describe("Test Quantum Portal Stake", function () {
  it("QPS initDefault Withdraw And SlashUser", async function () {
    const ctx = await getCtx();
    await deployDummyToken(ctx);
    const facPar = abi.encode(["address"], [ctx.token.address]);
    const qps = (await deployWithOwner(
      ctx,
      "QuantumPortalStake",
      ctx.owner,
      facPar
    )) as QuantumPortalStake;
    await qps.initDefault(ctx.token.address);
    const id = ctx.token.address;

    await qps.setLockSeconds(id, 500);
    await ctx.token.transfer(qps.address, Wei.from("1"));
    await qps.stakeFor(ctx.owner, id);

    let now = BigNumber.from(await getTime());
    let withTimeOf = await qps.withdrawTimeOf(id, ctx.owner);
    await advanceTimeAndBlock(200);

    await ctx.token.transfer(qps.address, Wei.from("10"));
    await qps.stakeFor(ctx.owner, id);
    now = withTimeOf;
    withTimeOf = await qps.withdrawTimeOf(id, ctx.owner);

    await advanceTimeAndBlock(200);

    await ctx.token.transfer(qps.address, Wei.from("2"));
    await qps.stakeFor(ctx.owner, id);
    now = withTimeOf;
    withTimeOf = await qps.withdrawTimeOf(id, ctx.owner);

    const amount = await (qps.stakeOf(id, ctx.owner));

    await qps.releaseWithdrawItems(ctx.owner, ctx.owner, amount);
    await throws(qps.withdraw(ctx.owner, id2, amount), "QPS: bad id");
    await throws(
      qps.releaseWithdrawItems(ZeroAddress, ctx.owner, amount), "QPS: staker requried");
  });

  it("QPS Slash User ", async function () { 
        const ctx = await getCtx();
        await deployDummyToken(ctx);
        const facPar = abi.encode(["address"], [ctx.token.address]);
        const qps = (await deployWithOwner(
          ctx,
          "QuantumPortalStake",
          ctx.owner,
          facPar
        )) as QuantumPortalStake;
        await qps.initDefault(ctx.token.address);
        const id = ctx.token.address;

        await qps.setLockSeconds(id, 500);
        await ctx.token.transfer(qps.address, Wei.from("1"));
        await qps.stakeFor(ctx.owner, id);

        let now = BigNumber.from(await getTime());
        let withTimeOf = await qps.withdrawTimeOf(id, ctx.owner);
        await advanceTimeAndBlock(200);

        await ctx.token.transfer(qps.address, Wei.from("10"));
        await qps.stakeFor(ctx.owner, id);
        now = withTimeOf;
        withTimeOf = await qps.withdrawTimeOf(id, ctx.owner);

        await advanceTimeAndBlock(200);

        await ctx.token.transfer(qps.address, Wei.from("2"));
        await qps.stakeFor(ctx.owner, id);
        now = withTimeOf;
        withTimeOf = await qps.withdrawTimeOf(id, ctx.owner);

        const amount = await(qps.stakeOf(id, ctx.owner));

        await qps.releaseWithdrawItems(ctx.owner, ctx.owner, amount);
        await throws(qps.withdraw(ctx.owner, id2, amount), "QPS: bad id");
        await throws(
          qps.releaseWithdrawItems(ZeroAddress, ctx.owner, amount),
          "QPS: staker requried"
        );

        const name = "FERRUM_QUANTUM_PORTAL_AUTHORITY_MGR";
        const version = "000.010";
        const msgHash = randomSalt();
        const expiry = expiryInFuture().toString();
        const salt = randomSalt();

        console.log("making signature for user slash");

        let multiSig = await getBridgeMethodCall(
          name,
          version,
          ctx.chainId,
          qps.address,
          "SLASH_STAKE",
          [
            { type: "address", name: "user", value: ctx.owner },
            { type: "uint256", name: "amount", value: amount },
            { type: "bytes32", name: "salt", value: salt },
            { type: "uint64", name: "expiry", value: expiry },
          ],
          [ctx.sks[0]]
        );
        console.log("about to slash a user");

        qps.slashUser(ctx.owner, amount, salt, expiry, multiSig.signature);
        console.log("successfully slash a user");
  });

});
