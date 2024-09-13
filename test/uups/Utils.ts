import hre from "hardhat";
import { getCtx } from 'foundry-contracts/dist/test/common/Utils';
import { Wei } from 'foundry-contracts/dist/test/common/Utils';
import qpDeployModule from "../../ignition/modules/QPDeploy";


export async function deployAll() {
    let ctx = await getCtx();

    const {
        ledgerMgr: ledgerMgr1,
        poc: poc1,
        authMgr: authMgr1,
        feeConverterDirect,
        staking,
        minerMgr: minerMgr1,
    } = await hre.ignition.deploy(qpDeployModule)

    const {
        ledgerMgr: ledgerMgr2,
        poc: poc2,
        authMgr: authMgr2,
        minerMgr: minerMgr2,
    } = await hre.ignition.deploy(qpDeployModule)

    const chainId1 = await ledgerMgr1.realChainId()
    const chainId2 = 2

    await ctx.signers.owner.sendTransaction({to: ctx.wallets[0], value: Wei.from('1')});
    await ctx.signers.owner.sendTransaction({to: ctx.wallets[1], value: Wei.from('1')});

    const testFeeToken = await hre.ethers.deployContract("TestToken")
    
    return {
        ...ctx,
        chain1: {
            chainId: chainId1,
            ledgerMgr: ledgerMgr1,
            poc: poc1,
            autorityMgr: authMgr1,
            minerMgr: minerMgr1,
            token: testFeeToken,
            stake: staking,
            feeConverter: feeConverterDirect,
        },
        chain2: {
            chainId: chainId2,
            ledgerMgr: ledgerMgr2,
            poc: poc2,
            autorityMgr: authMgr2,
            minerMgr: minerMgr2,
            token: testFeeToken,
            stake: staking,
            feeConverter: feeConverterDirect,
        }
    }
}
