import { ethers } from "hardhat";
import { QuantumPortalAuthorityMgr } from "../../../../typechain-types/QuantumPortalAuthorityMgr";
import { randomSalt, getBridgeMethodCall } from "foundry-contracts/dist/test/common/Eip712Utils";
import { expiryInFuture, getCtx } from 'foundry-contracts/dist/test/common/Utils';
import { TestContext } from "../../../common/Utils";

async function deployAm(ctx: TestContext) {
	const mgrFac = await ethers.getContractFactory("QuantumPortalAuthorityMgr");
    const mgr = await mgrFac.deploy() as QuantumPortalAuthorityMgr;
    await mgr.initialize(ctx.owner, 1, 1, 0, [ctx.wallets[0]]);
    return mgr;
}

describe("Test qp authority manager", function () {
	it('qpam can verify a properly signed message', async function() {
        console.log("O LA LA")
        const ctx = await getCtx();
        console.log("O LA LA2")
        const am = await deployAm(ctx);

        const action = '2';
        const msgHash = randomSalt();
        const expiry = expiryInFuture().toString();
        const salt = randomSalt();

        const name = "FERRUM_QUANTUM_PORTAL_AUTHORITY_MGR";
        const version = "000.010";

        let multiSig = await getBridgeMethodCall(
            name, version, ctx.chainId,
            am.address,
            'ValidateAuthoritySignature',
			[
				{ type: 'uint256', name: 'action', value: action },
				{ type: 'bytes32', name: 'msgHash', value: msgHash },
                { type: 'bytes32', name:'salt', value: salt},
				{ type: 'uint64', name: 'expiry', value: expiry },
			]
			, [ctx.sks[0]]);
        console.log('Verify does not fail');
        await am.validateAuthoritySignature(action, msgHash, salt, expiry, multiSig.signature);
    });
});
