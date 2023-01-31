import { ethers } from "hardhat";
import { DummyToken } from "../../../typechain/DummyToken";
import { QuantumPortalLedgerMgrTest } from "../../../typechain/QuantumPortalLedgerMgrTest";
import { QuantumPortalPocTest } from "../../../typechain/QuantumPortalPocTest";
import { QuantumPortalAuthorityMgr } from '../../../typechain/QuantumPortalAuthorityMgr';
import { randomSalt } from "foundry-contracts/dist/test/common/Eip712Utils";
import { abi, deployWithOwner, expiryInFuture, getCtx, isAllZero, Salt, TestContext, ZeroAddress,  } from 
    'foundry-contracts/dist/test/common/Utils';
import { getBridgeMethodCall } from '../../bridge/BridgeUtilsV12';
import { keccak256 } from "ethers/lib/utils";
import { delpoyStake, deployMinerMgr } from "./poa/TestQuantumPortalStakeUtils";
import { QuantumPortalStake } from "../../../typechain-types/QuantumPortalStake";
import { ERC20 } from "foundry-contracts/dist/test/common/UniswapV2";
import { Token } from "@uniswap/sdk";
import { Signer } from "ethers";

export const FERRUM_TOKENS = {
    26000: '0x00',
}

export class QuantumPortalUtils {
    static async mine(
        chain1: number,
        chain2: number,
        source: QuantumPortalLedgerMgrTest,
        target: QuantumPortalLedgerMgrTest,
        minerSk: string,
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

        const mine = await target.minerMgr();
        const msgHash = await target.calculateBlockHash(
            sourceBlock[0].metadata.chainId.toString(),
            sourceBlock[0].metadata.nonce.toString(),
            txs);
        const expiry = expiryInFuture().toString();
        const salt = randomSalt();
        // Verify with a miner that has no stakes
        const multiSig = await getBridgeMethodCall(
            await mine.NAME(),
            await mine.VERSION(),
            chain1,
            mine.address,
            'MinerSignature',
            [
                { type: 'bytes32', name: 'msgHash', value: msgHash},
                { type: 'uint64', name: 'expiry', value: expiry},
                { type: 'bytes32', name: 'salt', value: salt},
            ],
            [minerSk]
        );
        await target.mineRemoteBlock(
            chain1,
            sourceBlock[0].metadata.nonce.toString(),
            txs,
            randomSalt(),
            expiry.toString(),
            multiSig.signature!,
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

    static async callFinalizeWithSignature(
        realChainId: number, // used for EIP-712 signature generation
        remoteChainId: number,
        mgr: QuantumPortalLedgerMgrTest,
        sourceManager: QuantumPortalLedgerMgrTest,
        authMgrAddr: string,
        finalizers: string[],
        finalizersSk: string[],
    ) {
        const block = await mgr.lastRemoteMinedBlock(remoteChainId);
        const lastFin = await mgr.lastFinalizedBlock(remoteChainId);
        console.log(block);
        const blockNonce = block.nonce.toNumber();
        const fin = lastFin.nonce.toNumber();
        if (blockNonce > fin) {
        console.log(`Calling mgr.finalize(${remoteChainId}, ${blockNonce})`);
        const expiry = expiryInFuture().toString();
        const salt = randomSalt();
        const finalizersHash = randomSalt();
        const FINALIZE_METHOD = 
            keccak256(
                Buffer.from("Finalize(uint256 remoteChainId,uint256 blockNonce,bytes32 finalizersHash,address[] finalizers,bytes32 salt,uint64 expiry)", 'utf-8')
            );
        const msgHash = keccak256(abi.encode(['bytes32', 'uint256', 'uint256', 'bytes32', 'address[]', 'bytes32', 'uint64'],
            [FINALIZE_METHOD, remoteChainId, blockNonce, finalizersHash, finalizers, salt, expiry]));

        const name = "FERRUM_QUANTUM_PORTAL_AUTHORITY_MGR";
        const version = "000.010";

        // Create the signature for the authority mgr contract
        console.log("Going to call bridgeMethodCall");
        let multiSig = await getBridgeMethodCall(
            name, version, realChainId,
            authMgrAddr,
            'ValidateAuthoritySignature',
			[
				{ type: 'uint256', name: 'action', value: '1' },
				{ type: 'bytes32', name: 'msgHash', value: msgHash },
                { type: 'bytes32', name:'salt', value: salt},
				{ type: 'uint64', name: 'expiry', value: expiry },
			]
			, finalizersSk);

        console.log("Returned from bridgeMethodCall");
        await mgr.finalize(remoteChainId,
            blockNonce,
            finalizersHash,
            finalizers,
            salt,
            expiry,
            multiSig.signature!,
            );
        }else {
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

    static async stakeAndDelegate(stake: QuantumPortalStake, amount: string, staker: string, delegatee: string, signer: Signer) {
        const id = await stake.STAKE_ID();
        const tokenAddress = await stake.baseToken(id);
        const token = new ERC20(tokenAddress);
        await (await token.token()).connect(signer).transfer(stake.address, await token.amountToMachine(amount));
        await stake.stake(staker, await stake.STAKE_ID());
        await stake.connect(signer).delegate(delegatee);
    }
}

export interface PortalContext extends TestContext {
    chain1: {
        chainId: number;
        ledgerMgr: QuantumPortalLedgerMgrTest;
        poc: QuantumPortalPocTest;
        token: DummyToken;
        autorityMgr: QuantumPortalAuthorityMgr;
        stake: QuantumPortalStake;
    },
    chain2: {
        chainId: number;
        ledgerMgr: QuantumPortalLedgerMgrTest;
        poc: QuantumPortalPocTest;
        token: DummyToken;
        autorityMgr: QuantumPortalAuthorityMgr;
        stake: QuantumPortalStake;
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

    // By default, both test ledger mgrs use the same authority mgr.
	const autorityMgrF = await ethers.getContractFactory("QuantumPortalAuthorityMgr");
	console.log('About to deploy the ledger managers');
    const autorityMgr = await autorityMgrF.deploy() as QuantumPortalAuthorityMgr;

    console.log('Deploying some tokens');
	const tokenData = abi.encode(['address'], [ctx.owner]);
    const tok1 = await deployWithOwner(ctx, 'DummyToken', ZeroAddress, tokenData);

    // Deploy staking and mining manager
    const stake = await delpoyStake(ctx, tok1.address);
    // const stake = await delpoyStake(ctx, FERRUM_TOKENS[ctx.chainId] || panick(`No FRM token is configured for chain ${ctx.chainId}`));
    const miningMgr = await deployMinerMgr(ctx, stake);

    console.log(`Registering a single authority ("${ctx.wallets[0]}"`);
    await autorityMgr.initialize(ctx.owner, 1, 1, 0, [ctx.wallets[0]]); 

    console.log(`Settting authority mgr (${autorityMgr.address}) and miner mgr ${miningMgr.address} on both QP managers`);
    await mgr1.updateAuthorityMgr(autorityMgr.address);
    await mgr1.updateMinerMgr(miningMgr.address);
    await mgr2.updateAuthorityMgr(autorityMgr.address);
    await mgr2.updateMinerMgr(miningMgr.address);

    await poc1.setManager(mgr1.address);
    await poc2.setManager(mgr2.address);
    await mgr1.updateLedger(poc1.address);
    await mgr2.updateLedger(poc2.address);

	return {...ctx,
        chain1: {
            chainId: 2600,
            ledgerMgr: mgr1,
            poc: poc1,
            autorityMgr,
            token: tok1,
            stake,
        },
        chain2: {
            chainId: 2,
            ledgerMgr: mgr2,
            poc: poc2,
            autorityMgr,
            token: tok1,
            stake,
        }
    } as PortalContext;
}
