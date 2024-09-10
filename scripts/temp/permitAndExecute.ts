import { Contract, FunctionFragment, randomBytes, Signer, TypedDataEncoder } from "ethers";
import hre from "hardhat";
import { loadQpDeployConfig, QpDeployConfig } from "../../scripts/utils/DeployUtils";
import {QuantumPortalGatewayUpgradeable} from "../../typechain-types";
const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';
require("dotenv").config({path: __dirname + '/localConfig/.env'});



async function main() {
    const conf: QpDeployConfig = loadQpDeployConfig(process.env.QP_CONFIG_FILE || DEFAULT_QP_CONFIG_FILE);
    const BETA_QUORUM_ID = "0x0000000000000000000000000000000000000457"
    
    const wallet1 = new hre.ethers.Wallet(process.env.TEMP_SIGNER2_KEY!, hre.ethers.provider)
    const wallet2 = new hre.ethers.Wallet(process.env.TEMP_SIGNER3_KEY!, hre.ethers.provider)
    const dev = new hre.ethers.Wallet(process.env.TEMP_OWNER_KEY!, hre.ethers.provider)
    
    const gatewayAddress = "0x3C9025571EA627431570C1aB2ea74617a1c30B40"
    const gateway = await hre.ethers.getContractAt("QuantumPortalGatewayUpgradeable", gatewayAddress, dev)

    // const pocAddress = "0x2cfdD29175a163f28C66324d593d8773287847cd"
    // const poc = await hre.ethers.getContractAt("QuantumPortalPocImplUpgradeable", pocAddress, dev)

    const newFeeTokenAddress = "0x0000000000000000000000000000000000026626"

    const salt = "0x" + Buffer.from(randomBytes(32)).toString("hex")
    const expiry = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 2 // 1 day
    const funcName = "setAdmin"
    const params = ["0x2cfdD29175a163f28C66324d593d8773287847cd"]
    const calldata = gateway.interface.encodeFunctionData(funcName, params)

    const multisig = await getMultisig(
        gatewayAddress,
        gatewayAddress,
        calldata,
        BETA_QUORUM_ID,
        salt,
        expiry,
        [wallet1, wallet2]
    )

    console.log(await gateway.VERSION())
    console.log(await gateway.devAccounts(dev))

    const tx = await gateway.permitAndExecuteCall(gatewayAddress, calldata, BETA_QUORUM_ID, salt, expiry, multisig.sig, {gasLimit: 500000})

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
    expiry,
    signers: Signer[]    
) => {    
    const domain = {
        name: "FERRUM_QUANTUM_PORTAL_GATEWAY",
        version: "000.010",
        chainId: 31337,
        verifyingContract
    };

    const types = {
        PermitCall: [
            { name: "target", type: "address" },
            { name: "data", type: "bytes" },
            { name: "quorumId", type: "address" },
            { name: "salt", type: "bytes32" },
            { name: "expiry", type: "uint64" }
        ],
    };

    const values = {
        target: targetContract,
        data,
        quorumId,
        salt,
        expiry
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