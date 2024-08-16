import hre from "hardhat";
import { getCtx } from 'foundry-contracts/dist/test/common/Utils';
import qpDeployModule from "../../ignition/modules/TestContext";
import { Wei } from 'foundry-contracts/dist/test/common/Utils';

export async function deployAll() {
    let ctx = await getCtx();

    const { 
        mgr1,
		mgr2,
		poc1,
		poc2,
		authMgr1,
		authMgr2,
		testFeeToken,
		feeConverter,
		staking,
		minerMgr1,
		minerMgr2,
    } = await hre.ignition.deploy(qpDeployModule)

    const chainId1 = await mgr1.realChainId()
    const chainId2 = 2

    await poc1.updateFeeTarget()
    await poc2.updateFeeTarget()

    await ctx.signers.owner.sendTransaction({to: ctx.wallets[0], value: Wei.from('1')});
    await ctx.signers.owner.sendTransaction({to: ctx.wallets[1], value: Wei.from('1')});
    
    return {
        ...ctx,
        chain1: {
            chainId: chainId1,
            ledgerMgr: mgr1,
            poc: poc1,
            autorityMgr: authMgr1,
            minerMgr: minerMgr1,
            token: testFeeToken,
            stake: staking,
            feeConverter,
        },
        chain2: {
            chainId: chainId2,
            ledgerMgr: mgr2,
            poc: poc2,
            autorityMgr: authMgr2,
            minerMgr: minerMgr2,
            token: testFeeToken,
            stake: staking,
            feeConverter,
        }
    }
}
