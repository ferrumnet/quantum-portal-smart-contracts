import { getCtx, Wei, ZeroAddress } from 
    'foundry-contracts/dist/test/common/Utils';
import { deployAll, deployWFRM } from "./QuantumPortalUtils";
import { ethers } from 'hardhat';
import { QuantumPortalGatewayUpgradeable } from '../../../typechain-types';
import { delpoyStake } from './poa/TestQuantumPortalStakeUtils';

const _it = (a: any, b: any) => () => {};


describe("Test qp with native fees", function () {
  it('Stake on the FRM chain using native tokens', async function () {
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

	_it('Run a multi-chain tx with native fees', async function() {
    const ctx = await deployAll();
  });
});
