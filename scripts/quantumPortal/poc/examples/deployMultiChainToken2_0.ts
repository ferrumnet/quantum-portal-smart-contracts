import { ethers } from "hardhat";
import { abi, deployUsingDeployer, isAllZero, panick } from "../../../../test/common/Utils";
import { MitlChainToken2Client } from "../../../../typechain/MitlChainToken2Client";
import { MitlChainToken2Master } from "../../../../typechain/MitlChainToken2Master";
import { DEPLOYER_CONTRACT, DEPLPOY_SALT_1 } from "../../../consts";

const MASTER_CHAIN_ID = 4;
const CLIENT_CHAIN_ID = 97;
const deployedAddrMaster = '0xe7d0c9379edcc9478f9fa0284879edc54ff9ce79';
const deployedAddrClient = '0x06adea25a007c5de6b2e582459668c4f4a9b9653';
const qpPoc = '0x2c24a6b225b4c82d3241f5c7c037cc374a979b17';

async function con(addr: string, name: string) {
    const f = await ethers.getContractFactory(name);
    const c = await f.attach(addr);
    if (await c.deployed()) {
        return c;
    }
    return undefined;
}

async function deployMaster(owner: string) {
    if (!!deployedAddrMaster) {
        return deployedAddrMaster;
    }
    const initData = abi.encode(['address', 'uint256'], [qpPoc, 0]);
    const tok = await deployUsingDeployer('MitlChainToken2Master', owner, initData, DEPLOYER_CONTRACT,
        DEPLPOY_SALT_1) as MitlChainToken2Master;
    return tok.address;
}

async function deployClient(owner: string) {
    if (!deployedAddrMaster) {
        throw new Error('Master must be deployed first');
    }
    if (!!deployedAddrClient) {
        return deployedAddrClient;
    }
    const initData = abi.encode(['address', 'uint256'], [qpPoc, 0]);
    const tok = await deployUsingDeployer('MitlChainToken2Client', owner, initData, DEPLOYER_CONTRACT,
        DEPLPOY_SALT_1) as MitlChainToken2Client;
    return tok.address;
}

async function configMaster(addr: string) {
    const m = await con(addr, 'MitlChainToken2Master') as MitlChainToken2Master;
    let totalSupplyMaster = (await m.totalSupply()).toString();
    if (totalSupplyMaster === '0') {
        console.log('RUNNING INIT MINT ON MASTER');
        await m.initialMint();
    }

    if (CLIENT_CHAIN_ID && deployedAddrClient) {
        const curRem = await m.remotes(CLIENT_CHAIN_ID);
        if (isAllZero(curRem)) {
            console.log('SETTING REMOTE ON MASTER')
            await m.setRemote(CLIENT_CHAIN_ID, deployedAddrClient);
        }
    } else {
        console.log('NOT ABLE TO SET REMOTE YET. TRY AGAIN!')
    }
}

async function configClient(addr: string) {
    const m = await con(addr, 'MitlChainToken2Client') as MitlChainToken2Client;
    const master = await m.masterContract();
    if (isAllZero(master)) {
        console.log('SETTING MASTER CHAIN ID ON CLIENT');
        await m.setMasterChainId(MASTER_CHAIN_ID);
        console.log('SETTING MASTER CONTRACT ON CLIENT');
        await m.setMasterContract(deployedAddrMaster);
    }
}

async function main() {
    const owner: string = process.env.OWNER || panick('provide OWNER');
    const mode: string = process.env.MODE || panick('provide MODE = MASTER or CLIENT');

    if (mode === 'MASTER') {
        const addr = await deployMaster(owner);
        await configMaster(addr);
    } else if (mode === 'CLIENT') {
        const addr = await deployClient(owner);
        await configClient(addr);
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
