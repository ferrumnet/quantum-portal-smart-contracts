import hre from "hardhat";
import { loadQpDeployConfig, QpDeployConfig } from "../scripts/utils/DeployUtils";
const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';

interface Contract {
    name: string,
    addr: string,
}

async function main() {

    const conf: QpDeployConfig = loadQpDeployConfig(process.env.QP_CONFIG_FILE || DEFAULT_QP_CONFIG_FILE);

    console.log(conf)
    
    const qpContracts: Contract[] = [
        {
            name: "QuantumPortalGatewayUpgradeable",
            addr: conf.QuantumPortalGateway!
        },
        {
            name: "QuantumPortalPocImplUpgradeable",
            addr: conf.QuantumPortalPoc!
        },
        {
            name: "QuantumPortalLedgerMgrImplUpgradeable",
            addr: conf.QuantumPortalLedgerMgr!
        },
        {
            name: "QuantumPortalAuthorityMgrUpgradeable",
            addr: conf.QuantumPortalAuthorityMgr!
        },
        {
            name: "QuantumPortalFeeConverterDirectUpgradeable",
            addr: conf.QuantumPortalFeeConvertorDirect!
        },
        {
            name: "QuantumPortalMinerMgrUpgradeable",
            addr: conf.QuantumPortalMinerMgr!
        },
        {
            name: "QuantumPortalStakeWithDelegateUpgradeable",
            addr: conf.QuantumPortalStake!
        }
    ]

    // for (const qpContract of qpContracts) {
    //     const contract = await hre.ethers.getContractAt(qpContract.name, qpContract.addr);
    //     await contract.transferOwnership(await hre.ethers.getSigners()[0].getAddress());
    // }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });