import { abi, getCtx, Wei, ZeroAddress } from 
    'foundry-contracts/dist/test/common/Utils';
import { deployAll, deployNativeFeeRepo, deployWFRM, QuantumPortalUtils } from "./QuantumPortalUtils";
import { ethers } from 'hardhat';
import { QuantumPortalGatewayUpgradeable } from '../../../typechain-types';
import { delpoyStake } from './poa/TestQuantumPortalStakeUtils';

const _it = (a: any, b: any) => () => {};

describe("Test qp with native fees", function () {
  _it('Stake on the FRM chain using native tokens', async function () {
	  const ctx = await getCtx();
    const wfrm = await deployWFRM();
    const gateFac = await ethers.getContractFactory("QuantumPortalGatewayUpgradeable");
    const gate = await gateFac.deploy(wfrm.target.toString()) as unknown as QuantumPortalGatewayUpgradeable;
    await gate.initialize(ctx.owner, ctx.owner);

    const stake = await delpoyStake(ctx, ZeroAddress, gate.target.toString(), wfrm.target.toString());
    await gate.upgrade(ZeroAddress, ZeroAddress, stake.target);
    console.log('Stake token is WFRM: ', await stake.baseToken(await stake.STAKE_ID()), await wfrm.target.toString());
    console.log('Stake to delegate!');
    await gate.stakeToDelegate(0, ctx.acc1, { value: Wei.from('10') });
    console.log('Token is ', Wei.to((await stake.stakeOf(await stake.STAKE_ID(), ctx.owner)).toString()));
    console.log('Token is ', Wei.to((await stake.delegateStake(ctx.acc1)).toString()));
  });

	it('Run a multi-chain tx with native fees', async function() {
    const ctx = await deployAll();
    await deployNativeFeeRepo(ctx);
    await ctx.chain1.token.transfer(ctx.chain1.poc.target, Wei.from('20')); // X-chain balance tx
    let feeAmount = await ctx.chain1.feeConverter.targetChainFixedFee(ctx.chain2.chainId, QuantumPortalUtils.FIXED_FEE_SIZE + 0 /* No method call*/)
    feeAmount = feeAmount + 10_000_000_000_000n // plus some var fee
    await ctx.chain1.poc.runWithValueNativeFee(
        ctx.chain2.chainId,
        ctx.acc1,
        ZeroAddress,
        ctx.chain1.token.target,
        '0x', { value: feeAmount });
    let remoteBal = await ctx.chain2.poc.remoteBalanceOf(ctx.chain1.chainId, ctx.chain1.token.target, ctx.acc1);
    await QuantumPortalUtils.mineAndFinilizeOneToTwo(ctx, 1);
    console.log('Mined and finalized');
    console.log("Now lets check our remote balance");
    console.log('Remote balance pre-mine is ', Wei.to(remoteBal.toString()));
    remoteBal = await ctx.chain2.poc.remoteBalanceOf(ctx.chain1.chainId, ctx.chain1.token.target, ctx.acc1);
    console.log('Remote balance post-mine is ', Wei.to(remoteBal.toString()));
  });
});
