import { ethers } from "hardhat";
import { DummyToken } from "../../../typechain/DummyToken";
import { QuantumPortalLedgerMgrTest } from "../../../typechain/QuantumPortalLedgerMgrTest";
import { QuantumPortalPocTest } from "../../../typechain/QuantumPortalPocTest";
import { QuantumPortalAuthorityMgr } from '../../../typechain/QuantumPortalAuthorityMgr';
import { randomSalt } from "foundry-contracts/test/common/Eip712Utils";
import { abi, deployWithOwner, getCtx, isAllZero, Salt, TestContext, ZeroAddress } from "../../common/Utils";

export class QuantumPortalUtils {
    static async mine(
        chain1: number,
        chain2: number,
        source: QuantumPortalLedgerMgrTest,
        target: QuantumPortalLedgerMgrTest,
    ): Promise<boolean> {
        const blockReady = await source.isLocalBlockReady(chain2);
        console.log('Local block ready?', blockReady)
        if (!blockReady) { return false; }
        const lastB = await source.lastLocalBlock(chain2);
        const nonce = lastB.nonce.toNumber();
        const lastMinedBlock = await target.lastRemoteMinedBlock(chain1);
        const minedNonce = lastMinedBlock.nonce.toNumber();
        console.log(`Local block (chain ${chain1}) nonce is ${nonce}. Remote mined block (chain ${chain2}) is ${minedNonce}`)
        if (minedNonce >= nonce) {
            console.log('Nothing to mine.');
            return false;
        }
        console.log('Last block is on chain1 for target c2 is', lastB);
        // Is block already mined?
        const alreadyMined = await QuantumPortalUtils.minedBlockHash(chain1, nonce, target);
        if (!!alreadyMined) {
            throw new Error(`Block is already mined at ${alreadyMined}`);
        }
        const sourceBlock = await source.localBlockByNonce(chain2, nonce);
        const txs = sourceBlock[1].map(tx => ({
            timestamp: tx.timestamp.toString(),
            remoteContract: tx.remoteContract.toString(),
            sourceMsgSender: tx.sourceMsgSender.toString(),
            sourceBeneficiary: tx.sourceBeneficiary.toString(),
            token: tx.token.toString(),
            amount: tx.amount.toString(),
            method: tx.method.toString(),
            gas: tx.gas.toString(),
        }));
        console.log('About to mine block',
            sourceBlock[0].metadata.chainId.toString(),
            sourceBlock[0].metadata.nonce.toString(),
            sourceBlock[0],
            txs);
        if (!txs.length) {
            console.log('Nothing to mine');
            return false;
        }
        const expiry = Math.round(Date.now() / 1000) + 3600 * 100;
        const sig = '0x'; // TODO: Generate the signature...
        await target.mineRemoteBlock(
            chain1,
            sourceBlock[0].metadata.nonce.toString(),
            txs,
            randomSalt(),
            expiry.toString(),
            sig,
        );
        return true;
    }

    static async finalize(
        chain: number,
        mgr: QuantumPortalLedgerMgrTest,
    ) {
        const block = await mgr.lastRemoteMinedBlock(chain);
        const lastFin = await mgr.lastFinalizedBlock(chain);
        const blockNonce = block.nonce.toNumber();
        const fin = lastFin.nonce.toNumber();
        if (blockNonce > fin) {
            console.log(`Calling mgr.finalize(${chain}, ${blockNonce.toString()})`);
            const expiry = Math.round(Date.now() / 1000) + 3600 * 100;
            const sig = '0x'; // TODO: Generate the signature...
            await mgr.finalize(chain,
                blockNonce.toString(),
                Salt,
                [],
                randomSalt(),
                expiry.toString(),
                sig,
                );
        } else {
            console.log('Nothing to finalize...')
        }
    }

    static async minedBlockHash(
        chain: number,
        nonce: number,
        mgr: QuantumPortalLedgerMgrTest,
    ): Promise<string | undefined> {
        const existingBlock = await mgr.minedBlockByNonce(chain, nonce);
        const block = existingBlock[0].blockHash.toString();
        return isAllZero(block) ? undefined : block;
    }
}

export interface PortalContext extends TestContext {
    chain1: {
        chainId: number;
        ledgerMgr: QuantumPortalLedgerMgrTest;
        poc: QuantumPortalPocTest;
        token: DummyToken;
        autorityMgr: QuantumPortalAuthorityMgr;
    },
    chain2: {
        chainId: number;
        ledgerMgr: QuantumPortalLedgerMgrTest;
        poc: QuantumPortalPocTest;
        token: DummyToken;
        autorityMgr: QuantumPortalAuthorityMgr;
    },
}

export async function deployAll(): Promise<PortalContext> {
	const ctx = await getCtx();
	const mgrFac = await ethers.getContractFactory("QuantumPortalLedgerMgrTest");
	console.log('About to deploy the ledger managers');
    const mgr1 = await mgrFac.deploy(26000) as QuantumPortalLedgerMgrTest;
    const mgr2 = await mgrFac.deploy(2) as QuantumPortalLedgerMgrTest;

	const pocFac = await ethers.getContractFactory("QuantumPortalPocTest");
	console.log('About to deploy the pocs');
    const poc1 = await pocFac.deploy(26000) as QuantumPortalPocTest;
    const poc2 = await pocFac.deploy(2) as QuantumPortalPocTest;

    await poc1.setManager(mgr1.address);
    await poc2.setManager(mgr2.address);
    await mgr1.updateLedger(poc1.address);
    await mgr2.updateLedger(poc2.address);

    console.log('Deploying some tokens');
	const tokenData = abi.encode(['address'], [ctx.owner]);
    const tok1 = await deployWithOwner(ctx, 'DummyToken', ZeroAddress, tokenData);

	return {...ctx,
        chain1: {
            chainId: 2600,
            ledgerMgr: mgr1,
            poc: poc1,
            token: tok1,
        },
        chain2: {
            chainId: 2,
            ledgerMgr: mgr2,
            poc: poc2,
            token: tok1,
        }
    } as PortalContext;
}
