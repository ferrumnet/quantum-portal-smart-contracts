import hre from "hardhat"
import deployModule from "./modules/QPDeploy"
import fs from "fs"
import yaml from "js-yaml"
import { loadQpDeployConfig, QpDeployConfig } from "../scripts/utils/DeployUtils";
import { FunctionFragment } from "ethers";
const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';

async function main() {
    const conf: QpDeployConfig = loadQpDeployConfig(process.env.QP_CONFIG_FILE || DEFAULT_QP_CONFIG_FILE);
    let gateway,
        ledgerMgr,
        poc,
        authMgr,
        feeConverterDirect,
        staking,
        minerMgr,
        owner,
        signer1,
        signer2,
        signer3,
        signer4,
        signer5,
        signer6,
        signer7,
        settings
    
    ({ gateway, ledgerMgr, poc, authMgr, feeConverterDirect, staking, minerMgr } = await hre.ignition.deploy(deployModule))

    owner = (await hre.ethers.getSigners())[0]
    signer1 = (await hre.ethers.getSigners())[1]
    signer2 = (await hre.ethers.getSigners())[2]
    signer3 = (await hre.ethers.getSigners())[3]
    signer4 = (await hre.ethers.getSigners())[4]
    signer5 = (await hre.ethers.getSigners())[5]
    signer6 = (await hre.ethers.getSigners())[6]
    signer7 = (await hre.ethers.getSigners())[7]
    
    const BETA_QUORUM_ID = "0x0000000000000000000000000000000000000457"
    const PROD_QUORUM_ID = "0x00000000000000000000000000000000000008AE"
    const TIMELOCKED_PROD_QUORUM_ID = "0x0000000000000000000000000000000000000d05"

    const quorums = [
        {
            quorumId: BETA_QUORUM_ID,
            minSignatures: 2,
            addresses: [
                owner.address,
                signer1.address,
            ]
        },
        {   
            quorumId: PROD_QUORUM_ID,
            minSignatures: 2,
            addresses: [
                signer2.address,
                signer3.address,
                signer4.address,
            ]
        },
        {   
            quorumId: TIMELOCKED_PROD_QUORUM_ID,
            minSignatures: 2,
            addresses: [
                signer5.address,
                signer6.address,
                signer7.address
            ]
        },
    ];

    for (let i = 0; i < quorums.length; i++) {
        const quorum = quorums[i];
        await gateway.initializeQuorum(quorum.quorumId, 0, quorum.minSignatures, 0, quorum.addresses)
    }

    conf.QuantumPortalGateway = gateway.target as string
    conf.QuantumPortalPoc = poc.target as string
    conf.QuantumPortalLedgerMgr = ledgerMgr.target as string
    conf.QuantumPortalAuthorityMgr = authMgr.target as string
    conf.QuantumPortalFeeConvertorDirect = feeConverterDirect.target as string
    conf.QuantumPortalMinerMgr = minerMgr.target as string
    conf.QuantumPortalStake = staking.target as string
    
    const updatedConf = yaml.dump(conf);

    fs.writeFileSync(DEFAULT_QP_CONFIG_FILE, updatedConf, 'utf8');

    console.log(gateway.interface.getFunction("setCallAuthLevels", [["(address,address,bytes4)"]]).selector)
    console.log(FunctionFragment.getSelector("setCallAuthLevels", ["(address,address,bytes4)[]"]))
}


main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error)
    process.exit(1)
})
