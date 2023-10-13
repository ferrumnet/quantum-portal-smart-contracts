// Copyright 2019-2023 Ferrum Inc.
// This file is part of Ferrum.

// Ferrum is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// Ferrum is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with Ferrum.  If not, see <http://www.gnu.org/licenses/>
import { abi, deployUsingDeployer, Salt, Wei, ZeroAddress } from
  'foundry-contracts/dist/test/common/Utils';
var chai = require("chai");
var expect = chai.expect;
import { advanceTimeAndBlock } from "../../../common/TimeTravel";
import { sleep, SECONDS } from "../utils/setup";
import { deployAll, QuantumPortalUtils } from "../../../quantumPortal/poc/QuantumPortalUtils";

it("Multi Chain staking works", async () => {
  const ctx = await deployAll();
  console.log('Create the multi-chain staking');
  let init = abi.encode(['address', 'uint256'], [ctx.chain1.poc.address, ctx.chain1.chainId]);
  let stak = await deployUsingDeployer('MultiChainStakingMaster', ctx.owner, init, ctx.deployer.address, Salt) as MultiChainStakingMaster;
  console.log('Deployed staking at ', stak.address);
  await stak.init(
    [ctx.chain1.chainId],
    [stak.address],
    [ctx.chain1.token.address],
  );
  console.log('Setting reward token');
  await stak.setRewardToken(ctx.chain1.token.address);

  await ctx.chain1.token.approve(stak.address, Wei.from('100000'));
  console.log('Staking 10');
  await stak.stake(Wei.from('10'));
  // wait for the node to pickup and mine the transaction
  await sleep(120 * SECONDS);

  await stak.addRewards(Wei.from('5'));
  // wait for the node to pickup and mine the transaction
  await sleep(120 * SECONDS);

  await stak.enableRewardDistribution();

  const preBal = await Wei.bal(ctx.chain1.token, ctx.owner);
  await stak.closePsosition('0', ctx.chain1.chainId);
  const postBal = await Wei.bal(ctx.chain1.token, ctx.owner);
  console.log(`Pre vs post bal: ${preBal} => ${postBal}. We should have recived 15 tokens more`);
  // wait for the node to pickup and mine the transaction
  await sleep(120 * SECONDS);

  console.log('Now, the balances should have changed');

  // On chain2, we have no balance to withdraw
  const masterContractRemoteBalancePost = Wei.to(
    (await ctx.chain1.poc.remoteBalanceOf(ctx.chain2.chainId, ctx.chain2.token.address, stak.address)).toString());
  const userLocalBalancePost = Wei.to(
    (await ctx.chain2.poc.remoteBalanceOf(ctx.chain2.chainId, ctx.chain2.token.address, ctx.owner)).toString());

  console.log('To masterContractRemoteBalance:', masterContractRemoteBalancePre, masterContractRemoteBalancePost);
  console.log('To userLocalBalance:', userLocalBalancePre, userLocalBalancePost);

  await ctx.chain2.poc.withdraw(ctx.chain2.token.address, Wei.from('10'));
  const postBal = await Wei.bal(ctx.chain2.token, ctx.owner);

});
