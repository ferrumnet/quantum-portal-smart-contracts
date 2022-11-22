import { ethers } from "ethers";
import { QuantumPortalLedgerMgr } from "../../../typechain/QuantumPortalLedgerMgr";
import { QuantumPortalPoc } from "../../../typechain/QuantumPortalPoc";
import { QuantumPortalPoc__factory } from '../../../typechain/factories/QuantumPortalPoc__factory';
import { QuantumPortalLedgerMgr__factory } from '../../../typechain/factories/QuantumPortalLedgerMgr__factory';
import { QuantumPortalUtils } from "../../../test/quantumPortal/poc/QuantumPortalUtils";
import { ethers as hardhatEthers } from "hardhat";
import { panick, sleep } from "../../../test/common/Utils";

const getEnv = (env: string) => {
	const value = process.env[env];
	if (typeof value === 'undefined') {
	  console.warn(`${env} has not been set.`);
	  //throw new Error(`${env} has not been set.`);
	}
	return value || '0x123123123';
};

interface Portal {
    mgr: QuantumPortalLedgerMgr;
    // poc: QuantumPortalPoc;
}

class PairMiner {
    provider1: ethers.providers.JsonRpcProvider;
    provider2: ethers.providers.JsonRpcProvider;
    portal1: Portal;
    portal2: Portal;
    constructor(rpc1: string, rpc2: string, private mgr1: string, private mgr2: string) {
        this.provider1 = new ethers.providers.JsonRpcProvider(rpc1);
        this.provider2 = new ethers.providers.JsonRpcProvider(rpc2);
    }

    async init() {
        await this.provider1.ready;
        await this.provider2.ready;
        const signer1 = new ethers.Wallet(process.env.TEST_ACCOUNT_PRIVATE_KEY || panick('PRIVATE KEY'), this.provider1);
        const signer2 = new ethers.Wallet(process.env.TEST_ACCOUNT_PRIVATE_KEY || panick('PRIVATE KEY'), this.provider2);
        this.portal1 = {
            // poc: QuantumPortalPoc__factory.connect(poc1, this.provider1),
            mgr: QuantumPortalLedgerMgr__factory.connect(this.mgr1, signer1),
        };
        this.portal2 = {
            // poc: QuantumPortalPoc__factory.connect(poc2, this.provider2),
            mgr: QuantumPortalLedgerMgr__factory.connect(this.mgr2, signer2),
        };
        // console.log('SiG IS', this.portal1.mgr.signer, signer1);
        // console.log('SiG IS', this.portal2.mgr.signer, signer2);
    }

    async mine() {
        const chain1 = this.provider1.network.chainId;
        const chain2 = this.provider2.network.chainId;
        console.log(`Mining from ${chain1} -> ${chain2}`);
        // Try to finalize if any
        await QuantumPortalUtils.finalize(chain1, this.portal2.mgr as any);
        if (await QuantumPortalUtils.mine(
            chain1,
            chain2,
            this.portal1.mgr as any,
            this.portal2.mgr as any,
        )) {
            console.log(`Mined!`)
        } else {
            console.log('Didn\'t mine');
        }
    }
}

async function main() {
    // Connect to chain 1
    // and chain 2
    // and do mine and finalize in a loop from 1 -> 2
    // and 2 -> 1
    const rinkeby = "https://data-seed-prebsc-2-s3.binance.org:8545";
    const frm = 'https://rpc-mumbai.maticvigil.com/';
    // const frm = 'http://localhost:9933/';
    const mgr = '0x3d7d171d02d5f37c8eb0d3eea72859d5fc758ffb';
    const pair1 = new PairMiner(frm, rinkeby, mgr, mgr);
    await pair1.init();
    console.log('FRM Poc -> Rinkeby');
    await pair1.mine();
    const pair2 = new PairMiner(rinkeby, frm, mgr, mgr);
    await pair2.init();
    console.log('Rinkeby -> FRM Poc');
    await pair2.mine();
}
  
main()
	.then(() => process.exit(0))
	.catch(error => {
	  console.error(error);
	  process.exit(1);
});
