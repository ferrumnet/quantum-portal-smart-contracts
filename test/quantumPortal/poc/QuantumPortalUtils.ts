import { ethers } from "hardhat";
import { DummyToken } from "../../../typechain-types/DummyToken";
import { QuantumPortalLedgerMgrTest } from "../../../typechain-types/QuantumPortalLedgerMgrTest";
import { QuantumPortalPocTest } from "../../../typechain-types/QuantumPortalPocTest";
import { QuantumPortalAuthorityMgr } from '../../../typechain-types/QuantumPortalAuthorityMgr';
import { randomSalt } from "foundry-contracts/dist/test/common/Eip712Utils";
import { abi, deployWithOwner, expiryInFuture, getCtx, isAllZero, Salt, TestContext, Wei, ZeroAddress} from 
    'foundry-contracts/dist/test/common/Utils';
import { getBridgeMethodCall } from 'foundry-contracts/dist/test/common/Eip712Utils';
import { keccak256 } from "ethers/lib/utils";
import { delpoyStake, deployMinerMgr } from "./poa/TestQuantumPortalStakeUtils";
import { QuantumPortalStakeWithDelegate } from "../../../typechain-types/QuantumPortalStakeWithDelegate";
import { ERC20 } from "foundry-contracts/dist/test/common/UniswapV2";
import { Signer } from "ethers";
import { QuantumPortalMinerMgr } from "../../../typechain-types/QuantumPortalMinerMgr";
import { QuantumPortalFeeConverterDirect } from "../../../typechain-types/QuantumPortalFeeConverterDirect";
import { QuantumPortalState } from '../../../typechain-types/QuantumPortalState';
import { advanceTimeAndBlock } from "../../common/TimeTravel";
import { deployUsingDeployer } from "../../common/Utils";

export const FERRUM_TOKENS = {
    26000: '0x00',
}

export class QuantumPortalUtils {
    static FIXED_FEE_SIZE = 32*9;

    static async mine(
        chain1: number,
        chain2: number,
        source: QuantumPortalLedgerMgrTest,
        sourceState: QuantumPortalState,
        target: QuantumPortalLedgerMgrTest,
        targetState: QuantumPortalState,
        minerSk: string,
    ): Promise<boolean> {
        const blockReady = await source.isLocalBlockReady(chain2);
        console.log('Local block ready?', blockReady)
        if (!blockReady) { return false; }
        const lastB = await sourceState.getLastLocalBlock(chain2);
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
            methods: [tx.methods[0].toString()],
            fixedFee: tx.fixedFee.toString(),
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
        const [salt, expiry, signature] = await QuantumPortalUtils.generateSignatureForMining(
            target,
            chain1.toString(),
            sourceBlock[0].metadata.nonce.toString(),
            txs,
            minerSk
        );
        await target.mineRemoteBlock(
            chain1,
            sourceBlock[0].metadata.nonce.toString(),
            txs,
            salt,
            expiry,
            signature,
        );
        return true;
    }

    static async generateSignatureForMining(
        target: QuantumPortalLedgerMgrTest,
        sourceChainId: string,
        nonce: string,
        txs: any,
        minerSk: string,
    ) {
        const mineAddress = await target.minerMgr();
        const mineD = await ethers.getContractFactory('QuantumPortalMinerMgr');
        const mine = await mineD.attach(mineAddress) as QuantumPortalMinerMgr;
        const msgHash = await target.calculateBlockHash(
            sourceChainId,
            nonce,
            txs);
        console.log('Msg Hash for :', {
            sourceChainId,
            nonce,
            txs
        }, 'is: ', msgHash);
        const expiry = expiryInFuture().toString();
        const salt = randomSalt();
        // Verify with a miner that has no stakes
        const multiSig = await getBridgeMethodCall(
            await mine.NAME(),
            await mine.VERSION(),
            ethers.provider.network.chainId,
            mine.address,
            'MinerSignature',
            [
                { type: 'bytes32', name: 'msgHash', value: msgHash},
                { type: 'uint64', name: 'expiry', value: expiry},
                { type: 'bytes32', name: 'salt', value: salt},
            ],
            [minerSk]
        );
        return [salt, expiry, multiSig.signature!];
    }

    static async finalize(
        sourceChainId: number,
        mgr: QuantumPortalLedgerMgrTest,
        state: QuantumPortalState,
        finalizerSk: string,
        invalidBlocks: string[] = [],
    ) {
        const block = await mgr.lastRemoteMinedBlock(sourceChainId);
        const lastFin = await state.getLastFinalizedBlock(sourceChainId);
        const blockNonce = block.nonce.toNumber();
        const fin = lastFin.nonce.toNumber();
        if (blockNonce > fin) {
            console.log(`Calling mgr.finalize(${sourceChainId}, ${blockNonce.toString()})`);
            const expiry = expiryInFuture().toString();
            const salt = randomSalt();
            const finalizersHash = randomSalt();
            const FINALIZE_METHOD = 
                keccak256(
                    Buffer.from("Finalize(uint256 remoteChainId,uint256 blockNonce,bytes32 finalizersHash,address[] finalizers,bytes32 salt,uint64 expiry)", 'utf-8')
                );
            const msgHash = keccak256(abi.encode(['bytes32', 'uint256', 'uint256', 'bytes32', 'address[]', 'bytes32', 'uint64'],
                [FINALIZE_METHOD, sourceChainId, blockNonce, finalizersHash, [], salt, expiry]));
            console.log('Fin method msgHash', msgHash);
            
            const authorityAddr = await mgr.authorityMgr();
            const authorityF = await ethers.getContractFactory('QuantumPortalAuthorityMgr');
            const authority = await authorityF.attach(authorityAddr) as QuantumPortalAuthorityMgr;

            const name = await authority.NAME();
            const version = await authority.VERSION();
            // Create the signature for the authority mgr contract
            let multiSig = await getBridgeMethodCall(
                name, version, (await ethers.provider.getNetwork()).chainId,
                authorityAddr,
                'ValidateAuthoritySignature',
                [
                    { type: 'uint256', name: 'action', value: '1' },
                    { type: 'bytes32', name: 'msgHash', value: msgHash },
                    { type: 'bytes32', name:'salt', value: salt},
                    { type: 'uint64', name: 'expiry', value: expiry },
                ]
                , [finalizerSk]);
            console.log("Returned from bridgeMethodCall", multiSig.hash);
            const gas = await mgr.estimateGas.finalize(sourceChainId,
                blockNonce,
                invalidBlocks,
                finalizersHash,
                [], // TODO: Remove this parameter
                salt,
                expiry,
                multiSig.signature!,
                );
            console.log("Gas required to finalize is:", gas.toString());
            await mgr.finalize(sourceChainId,
                blockNonce,
                invalidBlocks,
                finalizersHash,
                [], // TODO: Remove this parameter
                salt,
                expiry,
                multiSig.signature!,
                );
        } else {
            console.log('Nothing to finalize...')
        }
    }

    static async callFinalizeWithSignature(
        realChainId: number, // used for EIP-712 signature generation
        remoteChainId: number,
        mgr: QuantumPortalLedgerMgrTest,
        state: QuantumPortalState,
        authMgrAddr: string,
        finalizers: string[],
        finalizersSk: string[],
        invalidBlocks: string[] = [],
    ) {
        const block = await mgr.lastRemoteMinedBlock(remoteChainId);
        const lastFin = await state.getLastFinalizedBlock(remoteChainId);
        console.log(block);
        const blockNonce = block.nonce.toNumber();
        const fin = lastFin.nonce.toNumber();
        if (blockNonce > fin) {
        console.log(`Calling mgr.finalize(${remoteChainId}, ${blockNonce})`);
        const expiry = expiryInFuture().toString();
        const salt = randomSalt();
        const finalizersHash = randomSalt();

        console.log("expiry", expiry);
        console.log("salt", salt);

        const FINALIZE_METHOD = 
            keccak256(
                Buffer.from("Finalize(uint256 remoteChainId,uint256 blockNonce,bytes32 finalizersHash,address[] finalizers,bytes32 salt,uint64 expiry)", 'utf-8')
            );
        console.log("This is the finalize method hash : ", FINALIZE_METHOD);
        console.log("remoteChainId : ", remoteChainId);
        console.log("blockNonce : ", blockNonce);
        const msgHash = keccak256(abi.encode(['bytes32', 'uint256', 'uint256', 'bytes32', 'address[]', 'bytes32', 'uint64'],
            [FINALIZE_METHOD, remoteChainId, blockNonce, finalizersHash, finalizers, salt, expiry]));
        console.log("This is the finalize msg hash : ", msgHash);


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
        console.log("This is the multisig : ", multiSig);
        console.log("Returned from bridgeMethodCall");
        await mgr.finalize(remoteChainId,
            blockNonce,
            invalidBlocks,
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

    static async mineAndFinilizeOneToOne(ctx: PortalContext, nonce: number, invalid: boolean = false) {
        let isBlRead = await ctx.chain1.ledgerMgr.isLocalBlockReady(ctx.chain1.chainId);
        if (!isBlRead) {
            await advanceTimeAndBlock(10000);
            console.log('Local block was not ready... Advancing time.');
        }
        isBlRead = await ctx.chain1.ledgerMgr.isLocalBlockReady(ctx.chain1.chainId);
        console.log('Local block is ready? ', isBlRead);

        let key = (await ctx.chain1.ledgerMgr.getBlockIdx(ctx.chain1.chainId, nonce)).toString();
        const txLen = await ctx.chain1.state.getLocalBlockTransactionLength(key);
        console.log('Tx len for block', key, 'is', txLen.toString());
        let tx = await ctx.chain1.state.getLocalBlockTransaction(key, 0); 
        await QuantumPortalUtils.stakeAndDelegate(ctx.chain1.ledgerMgr, ctx.chain1.stake, '10', ctx.owner, ctx.wallets[0], ctx.signers.owner, ctx.sks[0]);
        console.log('Staked and delegated...');
        const txs = [{
                    token: tx.token.toString(),
                    amount: tx.amount.toString(),
                    gas: tx.gas.toString(),
                    fixedFee: tx.fixedFee.toString(),
                    methods: tx.methods.length ? [tx.methods[0].toString()] : [],
                    remoteContract: tx.remoteContract.toString(),
                    sourceBeneficiary: tx.sourceBeneficiary.toString(),
                    sourceMsgSender: tx.sourceMsgSender.toString(),
                    timestamp: tx.timestamp.toString(),
            }];
        const [salt, expiry, signature] = await QuantumPortalUtils.generateSignatureForMining(
            ctx.chain1.ledgerMgr,
            ctx.chain1.chainId.toString(),
            nonce.toString(),
            txs,
            ctx.sks[0], // Miner...
        );
        await ctx.chain1.ledgerMgr.mineRemoteBlock(
            ctx.chain1.chainId,
            nonce.toString(),
            txs,
            salt,
            expiry,
            signature,
        );
        console.log('Now finalizing on chain1', invalid ? [nonce.toString()] : []);
        await QuantumPortalUtils.finalize(
            ctx.chain1.chainId,
            ctx.chain1.ledgerMgr,
            ctx.chain1.state,
            ctx.sks[0],
            invalid ? [nonce.toString()] : []
        );
    }

    static async mineAndFinilizeOneToTwo(ctx: PortalContext, nonce: number, invalid: boolean = false) {
        let isBlRead = await ctx.chain1.ledgerMgr.isLocalBlockReady(ctx.chain2.chainId);
        if (!isBlRead) {
            await advanceTimeAndBlock(10000);
            console.log('Local block was not ready... Advancing time.');
        }
        isBlRead = await ctx.chain1.ledgerMgr.isLocalBlockReady(ctx.chain2.chainId);
        console.log('Local block is ready? ', isBlRead);

        let key = (await ctx.chain1.ledgerMgr.getBlockIdx(ctx.chain2.chainId, nonce)).toString();
        const txLen = await ctx.chain1.state.getLocalBlockTransactionLength(key);
        console.log('Tx len for block', key, 'is', txLen.toString());
        let tx = await ctx.chain1.state.getLocalBlockTransaction(key, 0); 
        await QuantumPortalUtils.stakeAndDelegate(ctx.chain2.ledgerMgr, ctx.chain2.stake, '10', ctx.owner, ctx.wallets[0], ctx.signers.owner, ctx.sks[0]);
        console.log('Staked and delegated...');
        const txs = [{
                    token: tx.token.toString(),
                    amount: tx.amount.toString(),
                    gas: tx.gas.toString(),
                    fixedFee: tx.fixedFee.toString(),
                    methods: tx.methods.length ? [tx.methods[0].toString()] : [],
                    remoteContract: tx.remoteContract.toString(),
                    sourceBeneficiary: tx.sourceBeneficiary.toString(),
                    sourceMsgSender: tx.sourceMsgSender.toString(),
                    timestamp: tx.timestamp.toString(),
            }];
        const [salt, expiry, signature] = await QuantumPortalUtils.generateSignatureForMining(
            ctx.chain2.ledgerMgr,
            ctx.chain1.chainId.toString(),
            nonce.toString(),
            txs,
            ctx.sks[0], // Miner...
        );
        await ctx.chain2.ledgerMgr.mineRemoteBlock(
            ctx.chain1.chainId,
            nonce.toString(),
            txs,
            salt,
            expiry,
            signature,
        );
        console.log('Now finalizing on chain2', invalid ? [nonce.toString()] : []);
        await QuantumPortalUtils.finalize(
            ctx.chain1.chainId,
            ctx.chain2.ledgerMgr,
            ctx.chain2.state,
            ctx.sks[0],
            invalid ? [nonce.toString()] : []
        );
    }

    static async mineAndFinilizeTwoToOne(ctx: PortalContext, nonce: number, invalid: boolean = false) {
        let key = (await ctx.chain2.ledgerMgr.getBlockIdx(ctx.chain1.chainId, nonce)).toString();
        let tx = await ctx.chain2.state.getLocalBlockTransaction(key, nonce - 1); 
        // Commenting out because stake contract is shared in this test
        await ctx.chain1.token.transfer(ctx.acc1, Wei.from('10'));
        await QuantumPortalUtils.stakeAndDelegate(ctx.chain1.ledgerMgr, ctx.chain2.stake, '10', ctx.acc1, ctx.wallets[1], ctx.signers.acc1, ctx.sks[1]);
        const txs = [{
                    token: tx.token.toString(),
                    amount: tx.amount.toString(),
                    gas: tx.gas.toString(),
                    fixedFee: tx.fixedFee.toString(),
                    methods: [tx.methods[0].toString()],
                    remoteContract: tx.remoteContract.toString(),
                    sourceBeneficiary: tx.sourceBeneficiary.toString(),
                    sourceMsgSender: tx.sourceMsgSender.toString(),
                    timestamp: tx.timestamp.toString(),
            }];
        const [salt, expiry, signature] = await QuantumPortalUtils.generateSignatureForMining(
            ctx.chain1.ledgerMgr,
            ctx.chain2.chainId.toString(),
            nonce.toString(),
            txs,
            ctx.sks[1], // Miner...
        );
        await ctx.chain1.ledgerMgr.mineRemoteBlock(
            ctx.chain2.chainId,
            nonce.toString(),
            txs,
            salt,
            expiry,
            signature,
        );
        console.log('Now finalizing on chain1');
        await QuantumPortalUtils.finalize(
            ctx.chain2.chainId,
            ctx.chain1.ledgerMgr,
            ctx.chain1.state,
            ctx.sks[0],
            invalid ? [nonce.toString()] : []
        );
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

    static async stakeAndDelegate(mgr: QuantumPortalLedgerMgrTest,
        stake: QuantumPortalStakeWithDelegate,
        amount: string, staker: string, nodeOp: string, signer: Signer, nodeOpSk: string) {
        const id = await stake.STAKE_ID();
        const tokenAddress = await stake.baseToken(id);
        const token = new ERC20(tokenAddress);
        console.log(`Stake base token is: ${tokenAddress}`);

        // Instead of using a separate delegat, we use nodeOp address as delegate too
        const relationship = await stake.getDelegateForOperator(nodeOp);
        console.log(`Current delegate is ${relationship.delegate}`);
        const wallet = new ethers.Wallet(nodeOpSk, ethers.provider);
        if (relationship.delegate == ZeroAddress) {
            console.log(`Assigning operator to ${nodeOp}`);
            await stake.connect(wallet).assignOperator(nodeOp, {gasLimit: 2000000});
            console.log('Operator after', await stake.getDelegateForOperator(nodeOp));
        }

        await (await token.token()).connect(signer).transfer(stake.address, await token.amountToMachine(amount));
        await stake.connect(signer).stakeToDelegate(staker, nodeOp);
        console.log(`- Staked ${amount} for ${staker}`)
        console.log('Registering miner...');
        await mgr.connect(wallet).registerMiner({gasLimit: 2000000});
    }
}

export interface PortalContext extends TestContext {
    chain1: {
        chainId: number;
        ledgerMgr: QuantumPortalLedgerMgrTest;
        poc: QuantumPortalPocTest;
        token: DummyToken;
        autorityMgr: QuantumPortalAuthorityMgr;
        state: QuantumPortalState,
        minerMgr: QuantumPortalMinerMgr;
        stake: QuantumPortalStakeWithDelegate;
        feeConverter: QuantumPortalFeeConverterDirect;
    },
    chain2: {
        chainId: number;
        ledgerMgr: QuantumPortalLedgerMgrTest;
        poc: QuantumPortalPocTest;
        token: DummyToken;
        autorityMgr: QuantumPortalAuthorityMgr;
        state: QuantumPortalState,
        minerMgr: QuantumPortalMinerMgr;
        stake: QuantumPortalStakeWithDelegate;
        feeConverter: QuantumPortalFeeConverterDirect;
    },
}

export async function deployAll(): Promise<PortalContext> {
	const ctx = await getCtx();
	const mgrFac = await ethers.getContractFactory("QuantumPortalLedgerMgrTest");
	console.log('About to deploy the ledger managers');
    const mgr1 = await mgrFac.deploy(26000, {gasLimit: 8000000}) as QuantumPortalLedgerMgrTest;
    console.log('MGR LAUNCHED', await mgr1.VERSION());
    const mgr2 = await mgrFac.deploy(2) as QuantumPortalLedgerMgrTest;

    const chainId1 = await mgr1.realChainId();
    const chainId2 = 2;
    console.log(`Chain IDS: ${chainId1} / ${chainId2}`);

    console.log('Setting min stakes');
    await mgr1.updateMinerMinimumStake(Wei.from('10'));
    await mgr2.updateMinerMinimumStake(Wei.from('10'));

	const pocFac = await ethers.getContractFactory("QuantumPortalPocTest");
	console.log('About to deploy the pocs');
    const poc1 = await pocFac.deploy(26000) as QuantumPortalPocTest;
    const poc2 = await pocFac.deploy(2) as QuantumPortalPocTest;

    // By default, both test ledger mgrs use the same authority mgr.
    const authInitData1 = abi.encode(['address', 'address'], [poc1.address, mgr1.address]);
    const authInitData2 = abi.encode(['address', 'address'], [poc2.address, mgr2.address]);
	console.log('About to deploy the authority managers');
    const autorityMgr1 = await deployUsingDeployer('QuantumPortalAuthorityMgr', ctx.signers.acc1.address,
        authInitData1, ctx.deployer.address, randomSalt(), ctx.signers.acc1) as QuantumPortalAuthorityMgr;
    const autorityMgr2 = await deployUsingDeployer('QuantumPortalAuthorityMgr', ctx.signers.acc2.address,
        authInitData2, ctx.deployer.address, randomSalt(), ctx.signers.acc2) as QuantumPortalAuthorityMgr;

    console.log('Deploying some tokens');
	const tokenData = abi.encode(['address'], [ctx.owner]);
    const tok1 = await deployWithOwner(ctx, 'DummyToken', ZeroAddress, tokenData);

    console.log('Deploying direc fee converter');
    const feeConverterF = await ethers.getContractFactory('QuantumPortalFeeConverterDirect');
    const feeConverter = await feeConverterF.deploy();
    await feeConverter.updateFeePerByte(Wei.from('0.001'));

    console.log('Deploying staking');
    const stake = await delpoyStake(ctx, autorityMgr1.address, ZeroAddress, tok1.address);
    // const stake = await delpoyStake(ctx, FERRUM_TOKENS[ctx.chainId] || panick(`No FRM token is configured for chain ${ctx.chainId}`));
    console.log('Deploying mining mgr');
    const miningMgr1 = await deployMinerMgr(ctx, stake, poc1.address, mgr1.address, ctx.owner);
    const miningMgr2 = await deployMinerMgr(ctx, stake, poc2.address, mgr2.address, ctx.acc1); // To deploy a different contract.

    console.log(`Registering a single authority ("${ctx.wallets[0]}"`);
    await autorityMgr1.connect(ctx.signers.acc1).initialize(ctx.owner, 1, 1, 0, [ctx.wallets[0]]); 
    await autorityMgr2.connect(ctx.signers.acc2).initialize(ctx.owner, 1, 1, 0, [ctx.wallets[0], ctx.wallets[1]]); 

    console.log(`Settting authority mgr (${autorityMgr1.address}/${autorityMgr2.address}) and miner mgr ${miningMgr1.address} / ${miningMgr2.address} on both QP managers, and fee converter`);
    await mgr1.updateAuthorityMgr(autorityMgr1.address);
    await mgr1.updateMinerMgr(miningMgr1.address);
    await mgr1.updateFeeConvertor(feeConverter.address);
    await miningMgr1.updateRemotePeers([chainId2], [miningMgr2.address]);
    await mgr2.updateAuthorityMgr(autorityMgr2.address);
    await mgr2.updateMinerMgr(miningMgr2.address);
    await mgr2.updateFeeConvertor(feeConverter.address);
    await miningMgr2.connect(ctx.signers.acc1).updateRemotePeers([chainId1], [miningMgr1.address]);

    console.log(`Deploying QP State`);
    const stateF = await ethers.getContractFactory('QuantumPortalState');
    const state1 = await stateF.deploy() as QuantumPortalState;
    await state1.setMgr(mgr1.address);
    await state1.setLedger(poc1.address);
    const state2 = await stateF.deploy() as QuantumPortalState;
    await state2.setMgr(mgr2.address);
    await state2.setLedger(poc2.address);

    await poc1.setManager(mgr1.address, state1.address);
    await poc1.setFeeTarget(miningMgr1.address);
    await poc1.setFeeToken(tok1.address);
    await miningMgr1.updateBaseToken(tok1.address);
    await poc2.setManager(mgr2.address, state2.address);
    await poc2.setFeeTarget(miningMgr2.address);
    await poc2.setFeeToken(tok1.address);
    await miningMgr2.connect(ctx.signers.acc1).updateBaseToken(tok1.address);
    await mgr1.updateLedger(poc1.address);
    await mgr1.updateState(state1.address);
    await mgr2.updateLedger(poc2.address);
    await mgr2.updateState(state2.address);
    console.log('Set.');

    console.log('Sending eth to the miner wallet');
    await ctx.signers.owner.sendTransaction({to: ctx.wallets[0], value: Wei.from('1')});
    await ctx.signers.owner.sendTransaction({to: ctx.wallets[1], value: Wei.from('1')});

	return {
        ...ctx,
        chain1: {
            chainId: chainId1,
            ledgerMgr: mgr1,
            poc: poc1,
            autorityMgr: autorityMgr1,
            minerMgr: miningMgr1,
            state: state1,
            token: tok1,
            stake,
            feeConverter,
        },
        chain2: {
            chainId: chainId2,
            ledgerMgr: mgr2,
            poc: poc2,
            autorityMgr: autorityMgr2,
            minerMgr: miningMgr2,
            state: state2,
            token: tok1,
            stake,
            feeConverter,
        }
    } as PortalContext;
}

export async function estimateGasUsingEthCall(contract: string, encodedAbiForEstimateGas: string) {
    const res = await ethers.provider.call({
        data: encodedAbiForEstimateGas,
        to: contract,
    });
    console.log(`Result of eth_call: `, res);

    // Check if the result represents an error
    if (res.startsWith("0x08c379a0")) {
        const errorMessage = abi.decode(['string'], '0x'+res.substring(10)) as any as string;
        return Number.parseInt(errorMessage);
    } else {
        // Parse the result for successful execution (if needed)
        throw new Error('Estimate gas method call must fail, but this call will succeed');
    }
}