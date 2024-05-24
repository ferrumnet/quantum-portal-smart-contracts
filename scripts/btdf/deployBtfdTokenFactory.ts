import { ethers } from "hardhat";
import { QpDeployConfig, loadQpDeployConfig } from "../utils/DeployUtils";
import { TokenFactory } from "../../typechain-types/TokenFactory";
const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';

async function prep(conf: QpDeployConfig) {
    const facF = await ethers.getContractFactory('TokenFactory');
    if (!conf.QuantumPortalPoc) {
        throw new Error('QuantumPortalPoc not set');
    }
    if (!conf.QuantumPortalBtcWallet) {
        throw new Error('QuantumPortalBtcWallet not set');
    }

    console.log('Deploying BTFD', {portal: conf.QuantumPortalPoc, qpWallet: conf.QuantumPortalBtcWallet});
    const fac = await facF.deploy(conf.QuantumPortalPoc, conf.QuantumPortalBtcWallet) as TokenFactory;

    // Make sure the implementations are there
    console.log(`runeImplementation: ${await fac.runeImplementation()}`);
    console.log(`runeBeacon: ${await fac.runeBeacon()}`);
    console.log(`btcImplementation: ${await fac.btcImplementation()}`);
    console.log(`btcBeacon: ${await fac.btcBeacon()}`);
    console.log(`btc: ${await fac.btc()}`);
}

async function main() {
    const conf = loadQpDeployConfig(process.env.QP_CONFIG_FILE || DEFAULT_QP_CONFIG_FILE);
    await prep(conf);
}

main()
	.then(() => process.exit(0))
	.catch(error => {
	  console.error(error);
	  process.exit(1);
});
