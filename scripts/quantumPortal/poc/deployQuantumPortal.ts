import { ethers } from "hardhat";
import { abi, deployDummyToken, deployWithOwner, TestContext, ZeroAddress } from "foundry-contracts/dist/test/common/Utils";
import { panick, _WETH, deployUsingDeployer, contractExists, isAllZero } from "../../../test/common/Utils";
import { QuantumPortalPoc } from "../../../typechain/QuantumPortalPoc";
import { QuantumPortalLedgerMgr } from "../../../typechain/QuantumPortalLedgerMgr";
import { DEPLOYER_CONTRACT, DEPLPOY_SALT_1 } from "../../consts";
import { QuantumPortalAuthorityMgr } from "../../../typechain/QuantumPortalAuthorityMgr";
import { QuantumPortalStake } from "../../../typechain/QuantumPortalStake";
import { QuantumPortalMinerMgr } from "../../../typechain/QuantumPortalMinerMgr";

const STAKE_TOKEN_OBJ = {
    97 : "0x64544969ed7EBf5f083679233325356EbE738930", // USDC token on BSC
    80001 : "0x326C977E6efc84E512bB9C30f76E30c160eD06FB" // LINK token on Mumbai
}

const deployed = {
    QuantumPortalPoc: '0x9b3f3A08d6F0EBc77262b68e6239C6C57d8dC07d',
    QuantumPortalLedgerMgr: '0x465AAF9F6B8edb16D62344d4C100Bc69bC0e4AC7',
    QuantumPortalAuthorityMgr: '0x9367A0b0e80475EfADe4d4EdAd5bF64c5043C9D7',
    QuantumPortalMinerMgr: '0x98a5282993A5d8404A29327FADfB6CD9F3Fe8ABd',
    QuantumPortalStake: '0x58c35647e52E65Eda6a27D1501A7ff2CC17fc9A0',
    //QuantumPortalFeeManager: '',
};

interface Ctx {
    poc: QuantumPortalPoc;
    mgr: QuantumPortalLedgerMgr;
    auth: QuantumPortalAuthorityMgr;
    miner: QuantumPortalMinerMgr,
    stake: QuantumPortalStake
}

async function prep(owner: string) {
	const [deployer] = await ethers.getSigners();
	console.log("Account balance:", deployer.address, (await deployer.getBalance()).toString());
    const ctx: Ctx = {} as any;

    if (deployed.QuantumPortalPoc &&
        await (contractExists('QuantumPortalPocImpl', deployed.QuantumPortalPoc))) {
        console.log(`QuantumPortalPoc exists on `, deployed.QuantumPortalPoc);
	    const pocF = await ethers.getContractFactory("QuantumPortalPocImpl");
        ctx.poc = await pocF.attach(deployed.QuantumPortalPoc) as any;
    } else {
        const deped = await deployUsingDeployer('QuantumPortalPocImpl', owner, '0x',
        DEPLOYER_CONTRACT, DEPLPOY_SALT_1) as QuantumPortalPoc;
        console.log(`Deployed poc at `, deped.address);
        ctx.poc = deped;
    }
    if (deployed.QuantumPortalLedgerMgr &&
        await (contractExists('QuantumPortalLedgerMgrImpl', deployed.QuantumPortalLedgerMgr))) {
        console.log(`QuantumPortalLedgerMgr exists on `, deployed.QuantumPortalLedgerMgr);
	    const pocF = await ethers.getContractFactory("QuantumPortalLedgerMgrImpl");
        ctx.mgr = await pocF.attach(deployed.QuantumPortalLedgerMgr) as any;
    } else {
        const deped = await deployUsingDeployer('QuantumPortalLedgerMgrImpl', owner, '0x',
        DEPLOYER_CONTRACT, DEPLPOY_SALT_1) as QuantumPortalLedgerMgr;
        console.log(`Deployed QuantumPortalLedgerMgr  at `, deped.address);
        ctx.mgr = deped as any;
    }
    if (deployed.QuantumPortalAuthorityMgr &&
        await (contractExists('QuantumPortalAuthorityMgr', deployed.QuantumPortalAuthorityMgr))) {
        console.log(`QuantumPortalAuthorityMgr exists on `, deployed.QuantumPortalAuthorityMgr);
	    const authM = await ethers.getContractFactory("QuantumPortalAuthorityMgr");
        ctx.auth = await authM.attach(deployed.QuantumPortalAuthorityMgr) as any;
    } else {
        const deped = await deployUsingDeployer('QuantumPortalAuthorityMgr', owner, '0x',
        DEPLOYER_CONTRACT, DEPLPOY_SALT_1) as QuantumPortalAuthorityMgr;
        console.log(`Deployed auth at `, deped.address);
        ctx.auth = deped as any;
    }

    if (deployed.QuantumPortalStake &&
        await (contractExists('QuantumPortalStake', deployed.QuantumPortalStake))) {
        console.log(`QuantumPortalStake exists on `, deployed.QuantumPortalStake);
	    const authM = await ethers.getContractFactory("QuantumPortalStake");
        ctx.stake = await authM.attach(deployed.QuantumPortalStake) as any;
    } else {
        let stakeToken = STAKE_TOKEN_OBJ[(await ethers.provider.getNetwork()).chainId] || panick(`No stake token address for chain`);
        const initData = abi.encode(['address', 'address'], [stakeToken, ctx.auth.address]);
        const deped = await deployUsingDeployer('QuantumPortalStake', owner, initData,
        DEPLOYER_CONTRACT, DEPLPOY_SALT_1) as QuantumPortalStake;
        console.log(`Deployed stake at `, deped.address);
        ctx.stake = deped as any;
    }

    if (deployed.QuantumPortalMinerMgr &&
        await (contractExists('QuantumPortalMinerMgr', deployed.QuantumPortalMinerMgr))) {
        console.log(`QuantumPortalMinerMgr exists on `, deployed.QuantumPortalMinerMgr);
	    const authM = await ethers.getContractFactory("QuantumPortalMinerMgr");
        ctx.miner = await authM.attach(deployed.QuantumPortalMinerMgr) as any;
    } else {
        console.log('Deploying miner mgr for stake', ctx.stake.address);
        const initData = abi.encode(['address'], [ctx.stake.address]);
        const deped = await deployUsingDeployer('QuantumPortalMinerMgr', ZeroAddress, initData,
            DEPLOYER_CONTRACT, DEPLPOY_SALT_1) as QuantumPortalMinerMgr;
        console.log(`Deployed miner mgr at `, deped.address);
        ctx.miner = deped as any;
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
    const ctx = await prep(process.env.OWNER || panick('provide OWNER'));
    await configure(ctx);
}
  
main()
	.then(() => process.exit(0))
	.catch(error => {
	  console.error(error);
	  process.exit(1);
});
