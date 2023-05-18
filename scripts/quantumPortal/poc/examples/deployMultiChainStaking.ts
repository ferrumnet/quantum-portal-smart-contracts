import { ethers } from "hardhat";
import { UniV2Helper } from "../../../../test/common/UniV2";
import { abi } from "../../../../test/common/Utils";
import { MultiChainStakingClient } from "../../../../typechain/MultiChainStakingClient";
import { MultiChainStakingMaster } from "../../../../typechain/MultiChainStakingMaster";
import { DeployCliArgs, DeployTestHelper, readLine } from "./deployTestHelper";

interface Args extends DeployCliArgs {
    mode: 'MASTER' | 'CLIENT' | 'INIT_MASTER' | 'INIT_CLIENT';
}

interface Contracts {
    MultiChainStakingMaster: MultiChainStakingMaster;
    MultiChainStakingClient: MultiChainStakingClient;
}

async function configMaster(helper: DeployTestHelper<Args, Contracts>) {
    await helper.configMaster('MultiChainStakingMaster', 'MultiChainStakingClient');
}

async function configClient(helper: DeployTestHelper<Args, Contracts>) {
    await helper.configClient('MultiChainStakingMaster', 'MultiChainStakingClient');
}

async function main() {
    const helper = new DeployTestHelper<Args, Contracts>(['owner','mode;provide MODE = MASTER or CLIENT']);
    helper.MASTER_CHAIN_ID = 97; // bsc testnet
    helper.CLIENT_CHAIN_ID = 80001; // avax fuji testnet
    const ASTAR_CLIENT_CHAIN_ID = 0;
    await helper.init(
        (helper.args.mode === 'MASTER' || helper.args.mode === 'INIT_MASTER') ? helper.MASTER_CHAIN_ID : helper.CLIENT_CHAIN_ID,
        [
            {name: 'MultiChainStakingMaster', address: '0x53665C11792f0224232d6BC3152F9f3A9F739542', netId: helper.MASTER_CHAIN_ID},
            {name: 'MultiChainStakingClient', address: '0x8975062DD4105723207e104b257157d23488e9D0', netId: helper.CLIENT_CHAIN_ID}, // Add astar
        ]);

    if (helper.args.mode === 'MASTER') {
        const initData = abi.encode(['address', 'uint256'], [helper.qpPoc, 0]);
        await helper.tryDeploy('MultiChainStakingMaster', initData);
        await configMaster(helper);
    } else if (helper.args.mode === 'CLIENT') {
        const initData = abi.encode(['address', 'uint256'], [helper.qpPoc, 0]);
        await helper.tryDeploy('MultiChainStakingClient', initData);
        await configClient(helper);
    } else if (helper.args.mode === 'INIT_MASTER') {
        const clientTokenAddress = await readLine('What is the client STAKING token address?');
        const rewardTokenAddress = await readLine('What is the REWARD token address?');
        // const master = (await helper.con('0x1c96f909563cefd3a61e80dd41b290b442238b6c', 'MultiChainStakingMaster')) as MultiChainStakingMaster;
        const masterAddr = helper.deployed<MultiChainStakingMaster>('MultiChainStakingMaster').address;
        const clientAddr = helper.deployed<MultiChainStakingClient>('MultiChainStakingClient').address;
        const master = (await helper.con(masterAddr, 'MultiChainStakingMaster')) as MultiChainStakingMaster;
        const client = helper.deployed<MultiChainStakingClient>('MultiChainStakingClient');
        console.log('Setting client contract on the master...');
        await master.setRemote(helper.CLIENT_CHAIN_ID, client.address);
        console.log(`Inititalizing staking... `, {clientTokenAddress, rewardTokenAddress});
        await master.init([helper.CLIENT_CHAIN_ID, ASTAR_CLIENT_CHAIN_ID], [client.address, astar_contart], [clientTokenAddress, astar_token]);
        await master.setRewardToken(rewardTokenAddress);
        console.log(`=`.repeat(80));
        console.log(`Do not forget to "approve" staking contracs for tokens ${rewardTokenAddress}, and ${clientTokenAddress} on both chains.`)
    } else {
        throw new Error('Invalid MODE');
    }
}
  
main()
	.then(() => process.exit(0))
	.catch(error => {
	  console.error(error);
	  process.exit(1);
});
