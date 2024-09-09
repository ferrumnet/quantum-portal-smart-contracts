import { Contract, FunctionFragment, randomBytes, Signer, TypedDataEncoder } from "ethers";
import hre from "hardhat";
import { loadQpDeployConfig, QpDeployConfig } from "../../scripts/utils/DeployUtils";
import {QuantumPortalGatewayUpgradeable} from "../../typechain-types";
const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';
require("dotenv").config({path: __dirname + '/localConfig/.env'});




async function main() {
    const conf: QpDeployConfig = loadQpDeployConfig(process.env.QP_CONFIG_FILE || DEFAULT_QP_CONFIG_FILE);
    const BETA_QUORUM_ID = "0x0000000000000000000000000000000000000457"
    
    const wallet1 = new hre.ethers.Wallet(process.env.WALLET1_PRIVATE_KEY!, hre.ethers.provider)
    const wallet2 = new hre.ethers.Wallet(process.env.WALLET2_PRIVATE_KEY!, hre.ethers.provider)
    const dev = new hre.ethers.Wallet(process.env.QP_DEPLOYER_KEY!, hre.ethers.provider)
    
    const gatewayAddress = "0x21f64031935248c2765Fa6C0Dab4b68559e0d461"
    const gateway = await hre.ethers.getContractAt("QuantumPortalGatewayUpgradeable", gatewayAddress, dev) as unknown as  QuantumPortalGatewayUpgradeable

    const pocAddress = "0x0d2B09f34FD5888a01571ea56f52c9565639afca"
    const poc = await hre.ethers.getContractAt("QuantumPortalPocImplUpgradeable", pocAddress, dev)

    const newFeeTokenAddress = "0x0000000000000000000000000000000000026026"


    const salt = "0x" + Buffer.from(randomBytes(32)).toString("hex")
    const expiry = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 2 // 1 day
    const funcName = "setFeeToken"
    const params = [newFeeTokenAddress]
    const calldata = poc.interface.encodeFunctionData(funcName, params)

    const multisig = await getMultisig(
        pocAddress,
        gatewayAddress,
        calldata,
        BETA_QUORUM_ID,
        salt,
        [wallet1, wallet2]
    )

    const tx = await gateway.connect(dev).permitAndExecuteCall(pocAddress, calldata, BETA_QUORUM_ID, salt, expiry, multisig.sig, {gasLimit: 1000000})

    await tx.wait()
}

main().then(() => process.exit(0))


interface Sig {
    addr: string,
    sig: string
}

const getMultisig = async (
    targetContract:string,
    verifyingContract:string,
    data:string,
    quorumId:string,
    salt:string,
    signers: Signer[]    
) => {    
    const domain = {
        name: "FERRUM_QUANTUM_PORTAL_GATEWAY",
        version: "000.010",
        chainId: 8453,
        verifyingContract
    };

    const types = {
        PermitCall: [
            { name: "target", type: "address" },
            { name: "data", type: "bytes" },
            { name: "quorumId", type: "address" },
            { name: "salt", type: "bytes32" }
        ],
    };

    const values = {
        target: targetContract,
        data,
        quorumId,
        salt
    };

    const typedDataEncoder = new TypedDataEncoder(types)
    const typedData = typedDataEncoder.hashStruct("PermitCall", values)

    const sigs: Sig[] = [];
    
    for (const signer of signers) {
        const signature = await signer.signTypedData(domain, types, values);
        sigs.push({
            addr: await signer.getAddress(),
            sig: signature
        });
    }
    
    return {
        sig: sigsToMultisig(sigs),
        structHash: typedData
    };
}

const sigsToMultisig = (sigs: Sig[]): string => {
    let sig: string = '';
    let vs: string = '';

    // Sort the signatures based on the signer's address in descending order
    sigs.sort((s1, s2) => Buffer.from(s1.addr.replace('0x', ''), 'hex').compare(Buffer.from(s2.addr.replace('0x', ''), 'hex')));

    for (let i = 0; i < sigs.length; i++) {
        const sigWithoutPrefix = sigs[i].sig.replace('0x', '');

        const r = sigWithoutPrefix.slice(0, 64);
        const s = sigWithoutPrefix.slice(64, 128);
        const v = sigWithoutPrefix.slice(128, 130);

        sig += `${r}${s}`;

        vs += v;
    }

    // Pad the vs values to make their length a multiple of 64
    const padding = (vs.length % 64) === 0 ? 0 : 64 - (vs.length % 64);
    vs = vs + '0'.repeat(padding);

    sig = sig + vs;

    return '0x' + sig;
};