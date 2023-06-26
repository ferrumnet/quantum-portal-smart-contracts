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

import { expiryInFuture, seed0x as salt0x, throws, Wei, ZeroAddress } from
  'foundry-contracts/dist/test/common/Utils';
var chai = require("chai");
var expect = chai.expect;
import { advanceTimeAndBlock } from "../../../common/TimeTravel";
import { sleep, SECONDS } from "../utils/setup";
import { deployAll, QuantumPortalUtils } from "../../../quantumPortal/poc/QuantumPortalUtils";

it("Blocks are mined on destination/source chain", async () => {
  // mine test from EVM -> FRM chain
  // setup everything needed to mine
  const ctx = await deployAll();
  await ctx.chain1.token.transfer(ctx.chain1.poc.address, Wei.from('20'));

  const feeTarget = await ctx.chain1.poc.feeTarget();
  let feeAmount = await ctx.chain1.feeConverter.targetChainFixedFee(ctx.chain2.chainId, QuantumPortalUtils.FIXED_FEE_SIZE + 0)
  feeAmount = feeAmount.add(Wei.from('0.00001')); // plus some var fee
  await ctx.chain1.token.transfer(feeTarget, feeAmount);

  console.log(`Sent fee to ${feeTarget} - Worth ${feeAmount}. Now we can register the tx`);
  ctx.chain1.poc.runWithValue(
    ctx.chain2.chainId,
    ctx.acc1,
    ZeroAddress,
    ctx.chain1.token.address,
    '0x')
  // Check the block
  let lastLocalBlock = await ctx.chain1.ledgerMgr.lastLocalBlock(ctx.chain2.chainId);
  expect(lastLocalBlock.nonce).to.be.equal(1, 'Unexpected nonce!');

  let isBlockReady = await ctx.chain1.ledgerMgr.isLocalBlockReady(ctx.chain2.chainId);
  expect(isBlockReady).to.be.false;
  let lastNonce = await ctx.chain1.ledgerMgr.lastLocalBlock(ctx.chain2.chainId);
  let block = (await ctx.chain1.ledgerMgr.localBlockByNonce(ctx.chain2.chainId, 1))[0];
  let key = (await ctx.chain1.ledgerMgr.getBlockIdx(ctx.chain2.chainId, 1)).toString();
  let tx = await ctx.chain1.ledgerMgr.localBlockTransactions(key, 0);

  // wait for the node to pickup and mine the transaction
  await sleep(120 * SECONDS);
  await QuantumPortalUtils.stakeAndDelegate(ctx.chain1.stake, '10', ctx.owner, ctx.wallets[0], ctx.signers.owner);

  console.log('Now checking the work done');
  let remoteblock = (await ctx.chain2.ledgerMgr.lastMinedBlock(ctx.chain1.chainId))[0];
  expect(remoteblock).to.be.equal(block);


  // wait for the node to pickup and finalize the transaction
  await sleep(120 * SECONDS);
  await QuantumPortalUtils.stakeAndDelegate(ctx.chain1.stake, '10', ctx.owner, ctx.wallets[0], ctx.signers.owner);

  console.log('Now checking the work done');
  let finalized = (await ctx.chain2.ledgerMgr.lastFinalizedBlock(ctx.chain1.chainId))[0];
  expect(remoteblock).to.be.equal(block);
});
