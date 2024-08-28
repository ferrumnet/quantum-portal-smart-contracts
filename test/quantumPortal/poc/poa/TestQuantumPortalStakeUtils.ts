import { abi, deployDummyToken, deployWithOwner, TestContext, ZeroAddress } from "foundry-contracts/dist/test/common/Utils";
import { ethers } from "hardhat";
import { DummyToken, QuantumPortalMinerMgrUpgradeable, QuantumPortalStakeWithDelegateUpgradeable,
} from "../../../../typechain-types";

export async function delpoyStake(ctx: TestContext, auth: string, gateway: string, tokenAddress?: string) {
    if (!!tokenAddress) {
        console.log('Using token for stake', tokenAddress!);
        const tf = await ethers.getContractFactory('DummyToken');
        const tok = tf.attach(tokenAddress!) as any as DummyToken;
        ctx.token = tok;
    } else {
        await deployDummyToken(ctx);
    }
    const stkF = await ethers.getContractFactory('QuantumPortalStakeWithDelegateUpgradeable');
    const stk = await stkF.deploy() as any as QuantumPortalStakeWithDelegateUpgradeable;
    console.log('asd', tokenAddress || ctx.token.address, auth, ZeroAddress, gateway, ctx.owner);
    await stk.initialize(tokenAddress || ctx.token.address, auth, ZeroAddress, gateway, ctx.owner);
    const stakeId = await stk.STAKE_ID();
    console.log(`Statke with ID ${stakeId} was deployed`);
    return stk;
}

export async function  deployMinerMgr(stk: QuantumPortalStakeWithDelegateUpgradeable, portal: string, mgr: string, gateway: string, owner: string) {
    const initData = abi.encode(['address', 'address', 'address'], [stk.target, portal, mgr]);
    console.log("INIT for QuantumPortalMinerMgr", initData)
    const minF = await ethers.getContractFactory('QuantumPortalMinerMgrUpgradeable');
    const min = await minF.deploy() as any as QuantumPortalMinerMgrUpgradeable;
    await min.initialize(stk.target.toString(), portal, mgr, gateway, owner);
    return min;
}

