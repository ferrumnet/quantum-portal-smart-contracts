import { ethers } from "hardhat";
import { panick, _WETH, deployUsingDeployer, contractExists, isAllZero } from "../../../test/common/Utils";
import { QuantumPortalPoc } from "../../../typechain/QuantumPortalPoc";
import { QuantumPortalLedgerMgr } from "../../../typechain/QuantumPortalLedgerMgr";
import { DEPLOYER_CONTRACT, DEPLPOY_SALT_1 } from "../../consts";

const deployed = {
    QuantumPortalPoc: '',
    QuantumPortalLedgerMgr: '',
    // QuantumPortalPoc: '0x735af3bb15e4110cbbad0d74652da4f076879b97',
    // QuantumPortalLedgerMgr: '0x907383f7186d8b9ab51b7c879dbad7d71c56220e',
    // QuantumPortalPoc: '0x2c24a6b225b4c82d3241f5c7c037cc374a979b17',
    // QuantumPortalLedgerMgr: '0x3d7d171d02d5f37c8eb0d3eea72859d5fc758ffb',
    // QuantumPortalPoc: '0x010aC4c06D5aD5Ad32bF29665b18BcA555553151',
    // QuantumPortalLedgerMgr: '0xd36312D594852462d6760042E779164EB97301cd',
    QuantumPortalFeeManager: '', // Not yet implemented   
};

interface Ctx {
    poc: QuantumPortalPoc;
    mgr: QuantumPortalLedgerMgr;
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
        DEPLOYER_CONTRACT, DEPLPOY_SALT_1) as QuantumPortalPoc;
        console.log(`Deployed poc at `, deped.address);
        ctx.mgr = deped as any;
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
