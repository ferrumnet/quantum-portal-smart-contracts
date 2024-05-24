import { ethers } from "hardhat";
import { QuantumPortalPoc } from "../../typechain-types/QuantumPortalPoc";
import { QuantumPortalLedgerMgr } from "../../typechain-types/QuantumPortalLedgerMgr";
import { QuantumPortalAuthorityMgr } from "../../typechain-types/QuantumPortalAuthorityMgr";
import { QuantumPortalStakeWithDelegate } from "../../typechain-types/QuantumPortalStakeWithDelegate";
import { QuantumPortalMinerMgr } from "../../typechain-types/QuantumPortalMinerMgr";
import { QuantumPortalGateway } from "../../typechain-types/QuantumPortalGateway";
import { QuantumPortalFeeConverterDirect } from "../../typechain-types/QuantumPortalFeeConverterDirect";
import { QuantumPortalState } from "../../typechain-types/QuantumPortalState";
import { loadQpDeployConfig, QpDeployConfig } from "../utils/DeployUtils";
import * as acciiTable from 'ascii-table3';

const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';

async function getVersion(addr: string, ctr: string, methodCallers: {[k: string]: (c: any) => Promise<string>}) {
    const fac = await ethers.getContractFactory(ctr);
    const imp = fac.attach(addr) as any;
    const ver = await imp.VERSION();
    const vars = {};
    for (let mc of Object.keys(methodCallers)) {
        vars[mc] = await methodCallers[mc](imp);
    }
    return [ver, vars];
}

async function runCheck(conf: QpDeployConfig) {
    // Get chain ID
    const chainId = (await ethers.getDefaultProvider().getNetwork()).chainId;
    console.log('Connected to chhain: ', chainId);
    // Read all contracts. Get their versions.
    const [gatewayVer, gatewayPars] = await getVersion(conf.QuantumPortalGateway, 'QuantumPortalGateway', ({
        'WFRM': async (c: QuantumPortalGateway) => c.WFRM(),
        'admin': async (c: QuantumPortalGateway) => c.admin(),
        'owner': async (c: QuantumPortalGateway) => c.owner(),
        'quantumPortalPoc': async (c: QuantumPortalGateway) => c.quantumPortalPoc(),
        'quantumPortalLedgerMgr': async (c: QuantumPortalGateway) => c.quantumPortalLedgerMgr(),
        'quantumPortalStake': async (c: QuantumPortalGateway) => c.quantumPortalStake(),
    }));

    const quantumPortalPoc = gatewayPars['quantumPortalPoc'];
    const [quantumPortalPocVer, quantumPortalPocPars] = await getVersion(quantumPortalPoc, 'QuantumPortalPocImpl', ({
        'admin': async (c: QuantumPortalPoc) => c.admin(),
        'owner': async (c: QuantumPortalPoc) => c.owner(),
        'feeTarget': async (c: QuantumPortalPoc) => c.feeTarget(),
        'feeToken': async (c: QuantumPortalPoc) => c.feeToken(),
        'nativeFeeRepo': async (c: QuantumPortalPoc) => c.nativeFeeRepo(),
        'mgr': async (c: QuantumPortalPoc) => c.mgr(),
        'state': async (c: QuantumPortalPoc) => c.state(),
    }));

    const quantumPortalLedgerMgr = gatewayPars['quantumPortalLedgerMgr'];
    const [quantumPortalLedgerMgrVer, quantumPortalLedgerMgrPar] = await getVersion(quantumPortalLedgerMgr, 'QuantumPortalLedgerMgrImpl', ({
        'admin': async (c: QuantumPortalLedgerMgr) => c.admin(),
        'owner': async (c: QuantumPortalLedgerMgr) => c.owner(),
        'state': async (c: QuantumPortalLedgerMgr) => c.state(),
        'minerMgr': async (c: QuantumPortalLedgerMgr) => c.minerMgr(),
        'mineauthorityMgrrMgr': async (c: QuantumPortalLedgerMgr) => c.authorityMgr(),
        'feeConvertor': async (c: QuantumPortalLedgerMgr) => c.feeConvertor(),
        'varFeeTarget': async (c: QuantumPortalLedgerMgr) => c.varFeeTarget(),
        'fixedFeeTarget': async (c: QuantumPortalLedgerMgr) => c.fixedFeeTarget(),
        'stakes': async (c: QuantumPortalLedgerMgr) => c.stakes(),
    }));

    const quantumPortalStake = gatewayPars['quantumPortalStake'];
    const [quantumPortalStakeVer, quantumPortalStakePar] = await getVersion(quantumPortalStake, 'QuantumPortalStakeWithDelegate', ({
        'owner': async (c: QuantumPortalStakeWithDelegate) => c.owner(),
        'gateway': async (c: QuantumPortalStakeWithDelegate) => c.gateway(),
        'auth': async (c: QuantumPortalStakeWithDelegate) => c.auth(),
        'stakeVerifyer': async (c: QuantumPortalStakeWithDelegate) => c.stakeVerifyer(),
    }));

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
            ['QuantumPortalGateway', 'WFRM', gatewayPars.WFRM, conf.WETH[chainId]],
            ['QuantumPortalPocImpl', 'feeToken', quantumPortalPocPars.feeToken, conf.FRM[chainId]],
            ['QuantumPortalPocImpl', 'mgr', quantumPortalPocPars.mgr, conf.QuantumPortalLedgerMgr],
            ['QuantumPortalPocImpl', 'state', quantumPortalPocPars.state, conf.QuantumPortalState],
            // ['QuantumPortalLedgerMgrImpl', quantumPortalLedgerMgrPar.owner, quantumPortalLedgerMgrPar.admin],
            // ['QuantumPortalStakeWithDelegate', quantumPortalStakePar.owner, quantumPortalStakePar.admin],
        ]);
    console.log(table.toString());

}

async function main() {
    const conf = loadQpDeployConfig(process.env.QP_CONFIG_FILE || DEFAULT_QP_CONFIG_FILE);
    const ctx = await runCheck(conf);
}
  
main()
	.then(() => process.exit(0))
	.catch(error => {
	  console.error(error);
	  process.exit(1);
});
