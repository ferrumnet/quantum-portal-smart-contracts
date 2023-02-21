import { ethers } from "hardhat";
import { abi, ZeroAddress } from "foundry-contracts/dist/test/common/Utils";
import { panick, _WETH, deployUsingDeployer, contractExists, isAllZero } from "../../../test/common/Utils";
import { QuantumPortalPoc } from "../../../typechain/QuantumPortalPoc";
import { QuantumPortalLedgerMgr } from "../../../typechain/QuantumPortalLedgerMgr";
import { QuantumPortalAuthorityMgr } from "../../../typechain/QuantumPortalAuthorityMgr";
import { QuantumPortalStake } from "../../../typechain/QuantumPortalStake";
import { QuantumPortalMinerMgr } from "../../../typechain/QuantumPortalMinerMgr";
import { QuantumPortalGateway } from "../../../typechain/QuantumPortalGateway";
import { loadQpDeployConfig, QpDeployConfig } from "../../utils/DeployUtils";
import { Signer } from "ethers";

const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';

interface Ctx {
    gateway: QuantumPortalGateway;
    poc: QuantumPortalPoc;
    mgr: QuantumPortalLedgerMgr;
    auth: QuantumPortalAuthorityMgr;
    miner: QuantumPortalMinerMgr,
    stake: QuantumPortalStake
}

async function deployOrAttach(
    conf: QpDeployConfig,
    contractAddress: any,
    contractName: string,
    owner: string,
    initData: string,
    signer: Signer,
    deployer?: () => Promise<any>,
    postDeploy?: () => Promise<any>,
    ): Promise<[any, boolean]> {
    if (contractAddress &&
        await (contractExists(contractName, contractAddress))) {
        console.log(`${contractName} exists on `, contractAddress);
	    const pocF = await ethers.getContractFactory(contractName);
        return [pocF.attach(contractAddress) as any, false];
    } else {
        const deped = await deployUsingDeployer(contractName, owner, initData,
        conf.DeployerContract, conf.DeployerSalt) as QuantumPortalPoc;
        console.log(`Deployed poc at `, deped.address);
        return [deped, true];
    }
}

async function prep(conf: QpDeployConfig) {
    const deployerWallet = !!conf.DeployerKeys.DeployerContract ? new ethers.Wallet(conf.DeployerKeys.DeployerContract) : undefined;
    const qpWallet = !!conf.DeployerKeys.DeployerContract ? new ethers.Wallet(conf.DeployerKeys.Qp) : undefined;
    const ownerWallet = !!conf.DeployerKeys.Owner ? new ethers.Wallet(conf.DeployerKeys.Owner) : undefined;
    if (ownerWallet) {
        conf.Owner = await ownerWallet.getAddress();
    }
    console.log(`Using the following config: `, {
        ...conf,
        DeployerKeys: {},
    });

    if (!conf.DeployerContract) {
        console.log(`No deployer contract. Deploying one using ("${deployerWallet.address}")...`);
        const FerrumDep = await ethers.getContractFactory("FerrumDeployer");
        const ferrumDep = await FerrumDep.deploy();
        console.log("FerrumDep address:", ferrumDep.address);
        conf.DeployerContract = ferrumDep.address;
    }

    let newGateway: boolean;
    let newPoc: boolean;
    let newLedgerMgr: boolean;
    let newAut: boolean;
    let newStake: boolean;
    let newMinerMgr: boolean;
    const ctx: Ctx = {} as any;
    [ctx.gateway, newGateway] = await deployOrAttach(conf, conf.QuantumPortalGateway, 'QuantumPortalGateway', conf.Owner, '0x', qpWallet,
        async () => {
            console.log('Deploying gateway');
            const initData = abi.encode(['address'], [conf.WFRM]);
            const deped = await deployUsingDeployer('QuantumPortalGateway', conf.Owner, initData,
                conf.DeployerContract, conf.DeployerSalt) as QuantumPortalGateway;
            console.log(`Deployed qp gateway at `, deped.address);
            return deped;
        });

    [ctx.poc, newPoc] = await deployOrAttach(conf, conf.QuantumPortalPoc, ZeroAddress, '0x', 'QuantumPortalPocImpl', qpWallet,);
    [ctx.mgr, newLedgerMgr] = await deployOrAttach(conf, conf.QuantumPortalLedgerMgr, conf.Owner, '0x', 'QuantumPortalLedgerMgrImpl', qpWallet,);
    [ctx.auth, newAut] = await deployOrAttach(conf, conf.QuantumPortalAuthorityMgr, conf.Owner, '0x', 'QuantumPortalAuthorityMgr', qpWallet,);

    let stakeToken = conf.FRM[(await ethers.provider.getNetwork()).chainId] || panick(`No stake token address for chain`);
    const stakeInitData = abi.encode(['address', 'address'], [stakeToken, ctx.auth.address]);
    [ctx.stake, newStake] = await deployOrAttach(conf, conf.QuantumPortalStake, conf.Owner, stakeInitData, 'QuantumPortalStake', qpWallet,);
    if (newStake) {
        console.log('New stake. Clearing the miner mgr');
        conf.QuantumPortalMinerMgr = undefined;
    }

    const minerInitData = abi.encode(['address'], [ctx.stake.address]);
    [ctx.miner, newMinerMgr] = await deployOrAttach(conf, conf.QuantumPortalMinerMgr, ZeroAddress, minerInitData, 'QuantumPortalMinerMgr', qpWallet,);

    console.log('Now updating dependencies...');
    if (newPoc) {
        console.log('New POC. Updating ledgerMgr');
        await ctx.mgr.connect(qpWallet).updateLedger(ctx.poc.address);
    }
    if (newMinerMgr) {
        console.log('New miner mgr. Updating ledgerMgr');
        await ctx.mgr.connect(qpWallet).updateMinerMgr(ctx.miner.address);
    }
    if (newAut) {
        console.log('New auth mgr. Updating ledgerMgr');
        await ctx.mgr.connect(qpWallet).updateAuthorityMgr(ctx.auth.address);
    }
    console.log('Upgrade gateway', ctx.gateway.address);
    if (newPoc || newLedgerMgr || newStake || newGateway) {
        console.log('Updating gateway')
        await ctx.gateway.connect(qpWallet).upgrade(ctx.poc.address, ctx.mgr.address, ctx.stake.address, { from: conf.Owner });
    }

    return ctx;
}

async function configure(ctx: Ctx) {
    console.log('Configuring...')
    const ledger = (await ctx.mgr.ledger()).toString();
    console.log('Current: ctx.mgr.ledger', ledger);
    if (ledger !== ctx.poc.address) {
    // if (isAllZero(ledger)) {
        console.log('Updating to ', ctx.poc.address);
        await ctx.mgr.updateLedger(ctx.poc.address);
    }
    const mgr = (await ctx.poc.mgr()).toString();
    console.log('Current: ctx.poc.mgr', mgr);
    if (mgr !== ctx.mgr.address) {
    // if (isAllZero(mgr)) {
        console.log('Updating to ', ctx.mgr.address);
        await ctx.poc.setManager(ctx.mgr.address);
    }
    const auth = (await ctx.mgr.authorityMgr()).toString();
    if (auth != ctx.auth.address) {
        console.log('Updating auth to ', ctx.auth.address);
        await ctx.mgr.updateAuthorityMgr(ctx.auth.address);
    }

    const miner_mgr = (await ctx.mgr.minerMgr()).toString();
    if (miner_mgr != ctx.miner.address) {
        console.log('Updating miner to ', ctx.miner.address);
        await ctx.mgr.updateMinerMgr(ctx.miner.address);
    }
}

async function main() {
    const conf = loadQpDeployConfig(process.env.QP_CONFIG_FILE || DEFAULT_QP_CONFIG_FILE);
    const ctx = await prep(conf);
    await configure(ctx);
}
  
main()
	.then(() => process.exit(0))
	.catch(error => {
	  console.error(error);
	  process.exit(1);
});
