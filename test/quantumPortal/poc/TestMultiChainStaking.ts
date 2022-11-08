import { abi, deployUsingDeployer, Salt, Wei, ZeroAddress } from "../../common/Utils";
import { expect } from "chai";
import { advanceTimeAndBlock } from "../../common/TimeTravel";
import { deployAll, QuantumPortalUtils } from "./QuantumPortalUtils";
import { MultiChainStakingMaster } from '../../../typechain/MultiChainStakingMaster';
import { MultiChainStakingClient } from '../../../typechain/MultiChainStakingClient';

const _it = (a: any, b: any) => () => {};

describe("Test multi chain staking", function () {
	_it('Stake, add reward, and withdraw local', async function() {
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
        await stak.addRewards(Wei.from('5'));
        await stak.enableRewardDistribution();

        const preBal = await Wei.bal(ctx.chain1.token, ctx.owner);
        await stak.closePosition('0', ctx.chain1.chainId);
        const postBal = await Wei.bal(ctx.chain1.token, ctx.owner);
        console.log(`Pre vs post bal: ${preBal} => ${postBal}. We should have recived 15 tokens more`);
    });

    it('Stake local, also stake remote, and make sure it all works', async function() {
        const ctx = await deployAll();
        console.log('Mint the multi-chain staking');
        let init = abi.encode(['address', 'uint256'], [ctx.chain1.poc.address, ctx.chain1.chainId]);
        let stak = await deployUsingDeployer('MultiChainStakingMaster', ctx.owner, init, ctx.deployer.address, Salt) as MultiChainStakingMaster;
        await stak.init(
            [ctx.chain1.chainId, ctx.chain2.chainId],
            [stak.address, ZeroAddress],
            [ctx.chain1.token.address, ctx.chain2.token.address],
        );
        await stak.setRewardToken(ctx.chain1.token.address);

        let initClient = abi.encode(['address', 'uint256'], [ctx.chain2.poc.address, ctx.chain2.chainId]);
        let stakClient = await deployUsingDeployer('MultiChainStakingClient', ctx.owner, initClient, ctx.deployer.address, Salt) as MultiChainStakingClient;
        await stakClient.setMasterContract(stak.address);
        await stak.setRemote(ctx.chain2.chainId, stakClient.address);

        await ctx.chain2.token.approve(stakClient.address, Wei.from('100000'));
        await stakClient.stake(ctx.chain2.token.address, Wei.from('10'), '0');

        const userStakePre = await stak.stakes(ctx.chain2.chainId, ctx.owner);

        // Run a full mining round...
        console.log('Moving time forward and mining');
        await advanceTimeAndBlock(120); // Two minutes
        let mined = await QuantumPortalUtils.mine(ctx.chain2.chainId, ctx.chain1.chainId, ctx.chain2.ledgerMgr, ctx.chain1.ledgerMgr);
        expect(mined).to.be.true;
        await QuantumPortalUtils.finalize(ctx.chain2.chainId, ctx.chain1.ledgerMgr);

        const userStakePost = await stak.stakes(ctx.chain2.chainId, ctx.owner);
        console.log(`Owner, chain2 stake (as reflected on chain1) is changed as: ${userStakePre} => ${userStakePost}`);

        // Add rewards
        await ctx.chain1.token.approve(stak.address, Wei.from('100000'));
        await stak.addRewards(Wei.from('5'));
        await stak.enableRewardDistribution();

        // Now we close the position for chain2, (from chain1)
        // This should update the remoteBalance - on chain1 increased, and on chain2, decreased
        // however, no actual withdraw done.

        // On chain2, we have no balance to withdraw
        const masterContractRemoteBalancePre = Wei.to(
            (await ctx.chain1.poc.remoteBalanceOf(ctx.chain2.chainId, ctx.chain2.token.address, stak.address)).toString());
        const userLocalBalancePre = Wei.to(
            (await ctx.chain2.poc.remoteBalanceOf(ctx.chain2.chainId, ctx.chain2.token.address, ctx.owner)).toString());
        const preBal = await Wei.bal(ctx.chain2.token, ctx.owner);

        await stak.closePosition('0', ctx.chain2.chainId);

        console.log('Run a full mining round...');
        console.log('Moving time forward and mining for chain2 to 1');
        await advanceTimeAndBlock(120); // Two minutes
        mined = await QuantumPortalUtils.mine(ctx.chain1.chainId, ctx.chain2.chainId, ctx.chain1.ledgerMgr, ctx.chain2.ledgerMgr);
        expect(mined).to.be.true;
        await QuantumPortalUtils.finalize(ctx.chain1.chainId, ctx.chain2.ledgerMgr);

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

        console.log(`Pre vs post `, {masterContractRemoteBalancePre, userLocalBalancePre, preBal},
            {masterContractRemoteBalancePost, userLocalBalancePost, postBal});
    });
});
