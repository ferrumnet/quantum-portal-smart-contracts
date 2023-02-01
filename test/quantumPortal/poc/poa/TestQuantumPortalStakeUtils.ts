import { abi, deployDummyToken, deployWithOwner, TestContext, ZeroAddress } from "foundry-contracts/dist/test/common/Utils";
import { ethers } from "hardhat";
import { DummyToken } from "../../../../typechain-types/DummyToken";
import { QuantumPortalMinerMgr } from "../../../../typechain-types/QuantumPortalMinerMgr";
import { QuantumPortalStake } from "../../../../typechain-types/QuantumPortalStake";

export async function delpoyStake(ctx: TestContext, tokenAddress?: string) {
    if (!!tokenAddress) {
        const tf = await ethers.getContractFactory('DummyToken');
        const tok = await tf.attach(tokenAddress!) as DummyToken;
        ctx.token = tok;
    } else {
        await deployDummyToken(ctx);
    }
    const initData = abi.encode(['address', 'address'], [ctx.token.address, ctx.token.address]);
    console.log("INIT", initData)
    const stk = await deployWithOwner(ctx, 'QuantumPortalStake', ctx.acc1, initData
        ) as QuantumPortalStake;
    return stk;
}

export async function  deployMinerMgr(ctx: TestContext, stk: QuantumPortalStake) {
    const initData = abi.encode(['address'], [stk.address]);
    console.log("INIT for QuantumPortalMinerMgr", initData)
    const min = await deployWithOwner(ctx, 'QuantumPortalMinerMgr', ZeroAddress, initData
        ) as QuantumPortalMinerMgr;
    return min;
}

