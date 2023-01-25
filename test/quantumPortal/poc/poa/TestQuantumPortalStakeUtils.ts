import { abi, deployDummyToken, deployWithOwner, TestContext } from "foundry-contracts/dist/test/common/Utils";
import { QuantumPortalStake } from "../../../../typechain-types/QuantumPortalStake";

export async function delpoyStake(ctx: TestContext) {
    await deployDummyToken(ctx);
    const initData = abi.encode(['address', 'address'], [ctx.token.address, ctx.token.address]);
    console.log("INIT", initData)
    const stk = await deployWithOwner(ctx, 'QuantumPortalStake', ctx.acc1, initData
        ) as QuantumPortalStake;
    return stk;
}

