import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { throws, Wei, ZeroAddress } from 'foundry-contracts/dist/test/common/Utils';
import deployModule from "../../../ignition/modules/QPDeploy";
import { Contract, randomBytes, Signer, TypedDataEncoder } from "ethers";

const BETA_QUORUM_ID = "0x0000000000000000000000000000000000000457"
const PROD_QUORUM_ID = "0x00000000000000000000000000000000000008AE"
const TIMELOCKED_PROD_QUORUM_ID = "0x0000000000000000000000000000000000000d05"

describe("FerrumAdmin", function () {
    const expiry = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 3 // 1 day
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
        dev,
        settings
    
    async function deploymentFixture() {
        [owner, signer1, signer2, signer3, signer4, signer5, signer6, signer7, dev] = await hre.ethers.getSigners();
        
        ({ gateway, ledgerMgr, poc, authMgr, feeConverterDirect, staking, minerMgr } = await hre.ignition.deploy(deployModule))
    }

    beforeEach(async function () {
        await loadFixture(deploymentFixture);
        const quorums = [
            {
                minSignatures: 2,
                addresses: [
                    owner,
                    signer1,
                ]
            },
            {   
                minSignatures: 2,
                addresses: [
                    signer2,
                    signer3,
                    signer4,
                ]
            },
            {
                minSignatures: 3,
                addresses: [
                    signer5,
                    signer6,
                    signer7
                ]
            },
        ];
    
        await gateway.initializeQuorum(BETA_QUORUM_ID, 0, quorums[0].minSignatures, 0, quorums[0].addresses)
        await gateway.initializeQuorum(PROD_QUORUM_ID, 0, quorums[1].minSignatures, 0, quorums[1].addresses)
        await gateway.initializeQuorum(TIMELOCKED_PROD_QUORUM_ID, 0, quorums[2].minSignatures, 0, quorums[2].addresses)
    });

    it("Should have the correct version", async function () {
        console.log(await gateway.NAME())
        expect(await gateway.VERSION()).to.equal("000.010");
    });

    it("Quorum should no be able to permit a call to one that has no auth set", async function () {
        const salt = "0x" + Buffer.from(randomBytes(32)).toString("hex")
        

        const data = "0x12345678" // Arbitrary data

        // BETA_QUORUMID
        // Members: owner, signer1
        const multisig = await getMultisig(
            poc,
            gateway,
            data,
            await gateway.BETA_QUORUMID(),
            salt,
            expiry,
            [owner, signer1]
        )

        const tx =  gateway.permitCall(poc, data, await gateway.BETA_QUORUMID(), salt, expiry, multisig.sig)

        await expect(tx).to.be.revertedWith("FA: call auth not set")
    })

    it("devs should not be able to make a call without permission", async function () {
        await gateway.addDevAccounts([dev])
        const salt = "0x" + Buffer.from(randomBytes(32)).toString("hex")

        const funcName = "setFeeToken"
        const newFeeToken = await hre.ethers.deployContract("TestToken")
        const params = [newFeeToken.target]
        const calldata = poc.interface.encodeFunctionData(funcName, params)

        const tx = gateway.connect(dev).executePermittedCall(poc, calldata, await gateway.BETA_QUORUMID(), salt, expiry)

        await expect(tx).to.be.revertedWith("FA: not permitted")
    })

    it("Dev should be able to make a permitted call", async function () {
        await gateway.addDevAccounts([dev])
        await poc.transferOwnership(gateway)
        
        const salt = "0x" + Buffer.from(randomBytes(32)).toString("hex")

        const funcName = "setFeeToken"
        const newFeeToken = await hre.ethers.deployContract("TestToken")
        const params = [newFeeToken.target]
        const calldata = poc.interface.encodeFunctionData(funcName, params)

        const multisig = await getMultisig(
            poc,
            gateway,
            calldata,
            await gateway.BETA_QUORUMID(),
            salt,
            expiry,
            [owner, signer1]
        )

        await gateway.permitCall(poc, calldata, await gateway.BETA_QUORUMID(), salt, expiry, multisig.sig)

        const tx = gateway.connect(dev).executePermittedCall(poc, calldata, await gateway.BETA_QUORUMID(), salt, expiry)
        await expect(tx).to.emit(gateway, "CallExecuted").withArgs(multisig.structHash, poc.target, calldata)
        expect(await poc.feeToken()).to.equal(newFeeToken.target)
    })

    it("should be able to upgrade a contract after a permitted call", async function () {
        await gateway.addDevAccounts([dev])
        await poc.transferOwnership(gateway)
        
        const salt = "0x" + Buffer.from(randomBytes(32)).toString("hex")

        const funcName = "upgradeToAndCall"
        const newPoc = await hre.ethers.deployContract("QuantumPortalPocImplUpgradeable")
        const data = "0x"
        const params = [newPoc.target, data]
        const calldata = poc.interface.encodeFunctionData(funcName, params)

        const multisig = await getMultisig(
            poc,
            gateway,
            calldata,
            TIMELOCKED_PROD_QUORUM_ID,
            salt,
            expiry,
            [signer5, signer6, signer7]
        )

        await gateway.permitCall(poc, calldata, TIMELOCKED_PROD_QUORUM_ID, salt, expiry, multisig.sig)
        await hre.ethers.provider.send("evm_increaseTime", [60*60*24*1]);
        const tx = gateway.connect(dev).executePermittedCall(poc, calldata, TIMELOCKED_PROD_QUORUM_ID, salt, expiry)

        await expect(tx)
        .to.emit(gateway, "CallExecuted").withArgs(multisig.structHash, poc.target, calldata).and
        .to.emit(poc, "Upgraded").withArgs(newPoc.target)
    })
});

interface Sig {
    addr: string,
    sig: string
}

const getMultisig = async (
    targetContract:Contract,
    verifyingContract:Contract,
    data:string,
    quorumId:string,
    salt:string,
    expiry:number,
    signers: Signer[]    
) => {    
    const domain = {
        name: "FERRUM_QUANTUM_PORTAL_GATEWAY",
        version: "000.010",
        chainId: 31337,
        verifyingContract: verifyingContract.target as string
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
        target: targetContract.target,
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