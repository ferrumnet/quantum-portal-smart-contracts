import { abi, deployDummyToken, deployWithOwner, TestContext, ZeroAddress } from "foundry-contracts/dist/test/common/Utils";
import { ethers } from "hardhat";
import { DummyToken } from "../../../../typechain-types/DummyToken";
import { QuantumPortalMinerMgr } from "../../../../typechain-types/QuantumPortalMinerMgr";
import { QuantumPortalStakeWithDelegate } from "../../../../typechain-types/QuantumPortalStakeWithDelegate";

export async function delpoyStake(ctx: TestContext, auth: string, gateway: string, tokenAddress?: string) {
    if (!!tokenAddress) {
        console.log('Using token for stake', tokenAddress!);
        const tf = await ethers.getContractFactory('DummyToken');
        const tok = await tf.attach(tokenAddress!) as DummyToken;
        ctx.token = tok;
    } else {
        await deployDummyToken(ctx);
    }
    const initData = abi.encode(['address', 'address', 'address', 'address'],
        [ctx.token.address, auth, ZeroAddress, gateway]);
    console.log("INIT", initData);
    const stk = await deployWithOwner(ctx, 'QuantumPortalStakeWithDelegate', ZeroAddress, initData
        ) as QuantumPortalStakeWithDelegate;
    console.log('DEPED')
    const stakeId = await stk.STAKE_ID();
    console.log(`Statke with ID ${stakeId} was deployed`);
    return stk;
}

export async function  deployMinerMgr(ctx: TestContext, stk: QuantumPortalStakeWithDelegate, portal: string, mgr: string, owner: string) {
    const initData = abi.encode(['address', 'address', 'address'], [stk.address, portal, mgr]);
    console.log("INIT for QuantumPortalMinerMgr", initData)
    const min = await deployWithOwner(ctx, 'QuantumPortalMinerMgr', owner, initData
        ) as QuantumPortalMinerMgr;
    return min;
}

