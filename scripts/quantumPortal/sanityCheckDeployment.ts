import { ethers } from "hardhat";
import { QuantumPortalPoc } from "../../typechain-types";
import { QuantumPortalLedgerMgr } from "../../typechain-types";
import { QuantumPortalAuthorityMgr } from "../../typechain-types";
import { QuantumPortalStakeWithDelegate } from "../../typechain-types";
import { QuantumPortalMinerMgr } from "../../typechain-types";
import { QuantumPortalGateway } from "../../typechain-types";
import { QuantumPortalFeeConverterDirect } from "../../typechain-types";
import { QuantumPortalState } from "../../typechain-types";
import { loadQpDeployConfig, QpDeployConfig } from "../utils/DeployUtils";
import hre from "hardhat"
import * as acciiTable from 'ascii-table3';

const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';

async function getVersion(addr: string, ctr: string, methodCallers: {[k: string]: (c: any) => Promise<string>}) {
    const fac = await ethers.getContractFactory(ctr);
    const imp = fac.attach(addr) as any;
    const ver = await imp.VERSION();
    const vars = {};
    for (let mc of Object.keys(methodCallers)) {
        console.log(mc)
        vars[mc] = await methodCallers[mc](imp);
    }
    return [ver, vars];
}

async function runCheck(conf: QpDeployConfig) {
    // Get chain ID
    const chainId = 31337 // hre.network.config.chainId;
    console.log('Connected to chain: ', Number(chainId));
    // Read all contracts. Get their versions.
    const [gatewayVer, gatewayPars] = await getVersion(conf.QuantumPortalGateway!, 'QuantumPortalGateway', ({
        'WFRM': async (c: QuantumPortalGateway) => c.WFRM(),
        'admin': async (c: QuantumPortalGateway) => c.admin(),
        'owner': async (c: QuantumPortalGateway) => c.owner(),
        'quantumPortalPoc': async (c: QuantumPortalGateway) => c.quantumPortalPoc(),
        'quantumPortalLedgerMgr': async (c: QuantumPortalGateway) => c.quantumPortalLedgerMgr(),
        'quantumPortalStake': async (c: QuantumPortalGateway) => c.quantumPortalStake(),
    }));
    console.log('Gateway version: ', gatewayVer);
    console.log('Gateway parameters: ', gatewayPars);
    const quantumPortalPoc = gatewayPars['quantumPortalPoc'];
    const [quantumPortalPocVer, quantumPortalPocPars] = await getVersion(quantumPortalPoc, 'QuantumPortalPocImpl', ({
        'admin': async (c: QuantumPortalPoc) => c.admin(),
        'owner': async (c: QuantumPortalPoc) => c.owner(),
        'feeTarget': async (c: QuantumPortalPoc) => c.feeTarget(),
        'feeToken': async (c: QuantumPortalPoc) => c.feeToken(),
        'nativeFeeRepo': async (c: QuantumPortalPoc) => c.nativeFeeRepo(),
        'mgr': async (c: QuantumPortalPoc) => c.mgr(),
        // 'state': async (c: QuantumPortalPoc) => c.state(),
    }));
    console.log('QuantumPortalPocImpl version: ', quantumPortalPocVer);
    console.log('QuantumPortalPocImpl parameters: ', quantumPortalPocPars);

    const quantumPortalLedgerMgr = gatewayPars['quantumPortalLedgerMgr'];
    const [quantumPortalLedgerMgrVer, quantumPortalLedgerMgrPar] = await getVersion(quantumPortalLedgerMgr, 'QuantumPortalLedgerMgrImpl', ({
        'admin': async (c: QuantumPortalLedgerMgr) => c.admin(),
        'owner': async (c: QuantumPortalLedgerMgr) => c.owner(),
        // 'state': async (c: QuantumPortalLedgerMgr) => c.state(),
        'minerMgr': async (c: QuantumPortalLedgerMgr) => c.minerMgr(),
        'mineauthorityMgrrMgr': async (c: QuantumPortalLedgerMgr) => c.authorityMgr(),
        // 'feeConvertor': async (c: QuantumPortalLedgerMgr) => c.feeConvertor(),
        'varFeeTarget': async (c: QuantumPortalLedgerMgr) => c.varFeeTarget(),
        'fixedFeeTarget': async (c: QuantumPortalLedgerMgr) => c.fixedFeeTarget(),
    }));
    console.log('QuantumPortalLedgerMgrImpl version: ', quantumPortalLedgerMgrVer);
    console.log('QuantumPortalLedgerMgrImpl parameters: ', quantumPortalLedgerMgrPar);

    const quantumPortalStake = gatewayPars['quantumPortalStake'];
    const [quantumPortalStakeVer, quantumPortalStakePar] = await getVersion(quantumPortalStake, 'QuantumPortalStakeWithDelegate', ({
        'owner': async (c: QuantumPortalStakeWithDelegate) => c.owner(),
        'gateway': async (c: QuantumPortalStakeWithDelegate) => c.gateway(),
        'auth': async (c: QuantumPortalStakeWithDelegate) => c.auth(),
        'stakeVerifyer': async (c: QuantumPortalStakeWithDelegate) => c.stakeVerifyer(),
    }));
    console.log('QuantumPortalStakeWithDelegate version: ', quantumPortalStakeVer);
    console.log('QuantumPortalStakeWithDelegate parameters: ', quantumPortalStakePar);

    let table = new acciiTable.AsciiTable3('VERSIONS')
        .setHeading('Contract', 'Version')
        .setAlign(3, acciiTable.AlignmentEnum.CENTER)
        .addRowMatrix([
            ['QuantumPortalGateway', gatewayVer],
            ['QuantumPortalPocImpl', quantumPortalPocVer],
            ['QuantumPortalLedgerMgrImpl', quantumPortalLedgerMgrVer],
            ['QuantumPortalStakeWithDelegate', quantumPortalStakeVer],
        ]);
    console.log(table.toString());

    table = new acciiTable.AsciiTable3('CONFIGURED ADDRESSES ON GATEWAY')
        .setHeading('Contract', 'Gateway Address', 'Config Address', 'Same?')
        .setAlign(3, acciiTable.AlignmentEnum.CENTER)
        .addRowMatrix([
            ['QuantumPortalPocImpl', quantumPortalPoc, conf.QuantumPortalPoc, quantumPortalPoc === conf.QuantumPortalPoc],
            ['QuantumPortalLedgerMgrImpl', quantumPortalLedgerMgr, conf.QuantumPortalLedgerMgr, quantumPortalLedgerMgr === conf.QuantumPortalLedgerMgr],
            ['QuantumPortalStakeWithDelegate', quantumPortalStake, conf.QuantumPortalStake, quantumPortalStake === conf.QuantumPortalStake],
        ]);
    console.log(table.toString());

    // use asciiTable to print: Contract, owner, admin
    // TODO: More contracts
    table = new acciiTable.AsciiTable3('OWNERS AND ADMINS')
        .setHeading('Contract', 'Owner', 'Admin')
        .setAlign(3, acciiTable.AlignmentEnum.CENTER)
        .addRowMatrix([
            ['QuantumPortalGateway', gatewayPars.owner, gatewayPars.admin],
            ['QuantumPortalPocImpl', quantumPortalPocPars.owner, quantumPortalPocPars.admin],
            ['QuantumPortalLedgerMgrImpl', quantumPortalLedgerMgrPar.owner, quantumPortalLedgerMgrPar.admin],
            ['QuantumPortalStakeWithDelegate', quantumPortalStakePar.owner, quantumPortalStakePar.admin],
        ]);
    console.log(table.toString());

    // Contract, dependency, onchain, config, same
    table = new acciiTable.AsciiTable3('DEPENDENCY - ONCHAIN VS CONFIG')
        .setHeading('Contract', 'Dependency', 'On chain', 'Config', 'Same?')
        .setAlign(3, acciiTable.AlignmentEnum.CENTER)
        .addRowMatrix([
            ['QuantumPortalGateway', 'WFRM', gatewayPars.WFRM, conf.WETH[Number(chainId)]],
            ['QuantumPortalPocImpl', 'feeToken', quantumPortalPocPars.feeToken, conf.FRM[Number(chainId)]],
            ['QuantumPortalPocImpl', 'mgr', quantumPortalPocPars.mgr, conf.QuantumPortalLedgerMgr],
            // ['QuantumPortalPocImpl', 'state', quantumPortalPocPars.state, conf.QuantumPortalState],
            // ['QuantumPortalLedgerMgrImpl', quantumPortalLedgerMgrPar.owner, quantumPortalLedgerMgrPar.admin],
            // ['QuantumPortalStakeWithDelegate', quantumPortalStakePar.owner, quantumPortalStakePar.admin],
        ]);
    console.log(table.toString());

}

async function main() {
    const conf = await loadQpDeployConfig(process.env.QP_CONFIG_FILE || DEFAULT_QP_CONFIG_FILE);
    const ctx = await runCheck(conf);
}
  
main()
	.then(() => process.exit(0))
	.catch(error => {
	  console.error(error);
	  process.exit(1);
});
