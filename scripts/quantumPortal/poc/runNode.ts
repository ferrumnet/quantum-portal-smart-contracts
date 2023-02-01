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
	  throw new Error(`${env} has not been set.`);
	}
	return value;
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
        const signer1 = new ethers.Wallet(getEnv("TEST_ACCOUNT_PRIVATE_KEY"), this.provider1);
        const signer2 = new ethers.Wallet(getEnv("TEST_ACCOUNT_PRIVATE_KEY"), this.provider2);
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
        let authorityMgr = "0xA8900b24cf4284d9017C9Ee976C294b623fB07c8";
        let signer_addresses = [getEnv("OWNER")];
        let signer_pks = [getEnv("TEST_ACCOUNT_PRIVATE_KEY")];
        await QuantumPortalUtils.callFinalizeWithSignature(chain2, chain1, this.portal2.mgr as any, this.portal1.mgr as any, authorityMgr, 
                signer_addresses, signer_pks);
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
    const chain1 = getEnv("BSC_TESTNET_LIVE_NETWORK");
    const frm = getEnv("POLYGON_TEST_NETWORK");
    const mgr = '0x7Ae040f581bAc2876A2D32Fa4b8f668F029e04CD';
    const pair1 = new PairMiner(frm, chain1, mgr, mgr);
    await pair1.init();
    console.log('FRM Poc -> Chain1');
    await pair1.mine();
    const pair2 = new PairMiner(chain1, frm, mgr, mgr);
    await pair2.init();
    console.log('Chain1 -> FRM Poc');
    await pair2.mine();
}
  
main()
	.then(() => process.exit(0))
	.catch(error => {
	  console.error(error);
	  process.exit(1);
});
