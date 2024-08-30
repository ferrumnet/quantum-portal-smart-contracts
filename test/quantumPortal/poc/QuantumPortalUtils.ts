import { ethers } from "hardhat";
import { DummyToken,  } from "../../../typechain-types";
import { randomSalt } from "foundry-contracts/dist/test/common/Eip712Utils";
import { abi, deployWithOwner, expiryInFuture, getCtx, isAllZero, Salt, TestContext, Wei, ZeroAddress} from 
    'foundry-contracts/dist/test/common/Utils';
import { getBridgeMethodCall } from 'foundry-contracts/dist/test/common/Eip712Utils';
import { delpoyStake, deployMinerMgr } from "./poa/TestQuantumPortalStakeUtils";
import { ERC20 } from "foundry-contracts/dist/test/common/UniswapV2";
import { keccak256, Signer } from "ethers";
import { QuantumPortalState, QuantumPortalLedgerMgrUpgradeableTest, QuantumPortalGatewayUpgradeable,
        QuantumPortalPocUpgradeableTest, QuantumPortalFeeConverterDirectUpgradeable, QuantumPortalMinerMgrUpgradeable,
        QuantumPortalStakeWithDelegateUpgradeable, QuantumPortalAuthorityMgrUpgradeable,
 } from '../../../typechain-types';
import { advanceTimeAndBlock } from "../../common/TimeTravel";

export const FERRUM_TOKENS = {
    26000: '0x00',
}

export class QuantumPortalUtils {
    static FIXED_FEE_SIZE = 32*9;

    static async mine(
        chain1: number,
        chain2: number,
        source: QuantumPortalLedgerMgrUpgradeableTest,
        sourceState: QuantumPortalState,
        target: QuantumPortalLedgerMgrUpgradeableTest,
        minerSk: string,
    ): Promise<boolean> {
        const blockReady = await source.isLocalBlockReady(chain2);
        console.log('Local block ready?', blockReady)
        if (!blockReady) { return false; }
        const lastB = await sourceState.getLastLocalBlock(chain2);
        const nonce = Number(lastB.nonce.toString());
        const lastMinedBlock = await target.lastRemoteMinedBlock(chain1);
        const minedNonce = Number(lastMinedBlock.nonce.toString());
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
        target: QuantumPortalLedgerMgrUpgradeableTest,
        sourceChainId: string,
        nonce: string,
        txs: any,
        minerSk: string,
    ) {
        const mineAddress = await target.minerMgr();
        const mineD = await ethers.getContractFactory('QuantumPortalMinerMgrUpgradeable');
        const mine = await mineD.attach(mineAddress) as any as QuantumPortalMinerMgrUpgradeable;
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
            Number((await ethers.provider.getNetwork()).chainId),
            mine.target.toString(),
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
        mgr: QuantumPortalLedgerMgrUpgradeableTest,
        finalizerSk: string,
        invalidBlocks: string[] = [],
    ) {
        const block = await mgr.lastRemoteMinedBlock(sourceChainId);
        const lastFin = await mgr.getLastFinalizedBlock(sourceChainId);
        const blockNonce = Number(block.nonce);
        const fin = Number(lastFin.nonce);
        if (blockNonce > fin) {
            console.log(`Calling mgr.finalize(${sourceChainId}, ${blockNonce.toString()})`);
            const expiry = expiryInFuture().toString();
            const salt = randomSalt();
            const finalizersHash = randomSalt();
            const FINALIZE_METHOD = 
                keccak256(
                    Buffer.from("Finalize(uint256 remoteChainId,uint256 blockNonce,uint256[] invalidBlockNonces,bytes32 salt,uint64 expiry)", 'utf-8')
                );
            const msgHash = keccak256(abi.encode(['bytes32', 'uint256', 'uint256', 'uint256[]', 'bytes32', 'uint64'],
                [FINALIZE_METHOD, sourceChainId, blockNonce, [], salt, expiry]));
            console.log('Fin method msgHash', msgHash);
            
            const authorityAddr = await mgr.authorityMgr();
            const authorityF = await ethers.getContractFactory('QuantumPortalAuthorityMgrUpgradeable');
            const authority = authorityF.attach(authorityAddr) as unknown as  QuantumPortalAuthorityMgrUpgradeable;

            const name = await authority.NAME();
            const version = await authority.VERSION();
            // Create the signature for the authority mgr contract
            let multiSig = await getBridgeMethodCall(
                name, version, Number((await ethers.provider.getNetwork()).chainId),
                authorityAddr,
                'ValidateAuthoritySignature',
                [
                    { type: 'uint256', name: 'action', value: '1' },
                    { type: 'bytes32', name: 'msgHash', value: msgHash },
                    { type: 'bytes32', name:'salt', value: salt},
                    { type: 'uint64', name: 'expiry', value: expiry },
                ]
                , [finalizerSk]);
            console.log("Returned from bridgeMethodCall", multiSig.hash, name, version);
            const gas = await mgr.finalize.estimateGas(sourceChainId,
                blockNonce,
                invalidBlocks,
                salt,
                expiry,
                multiSig.signature!,
                );
            console.log("Gas required to finalize is:", gas.toString());
            await mgr.finalize(sourceChainId,
                blockNonce,
                invalidBlocks,
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
        mgr: QuantumPortalLedgerMgrUpgradeableTest,
        state: QuantumPortalState,
        authMgrAddr: string,
        finalizers: string[],
        finalizersSk: string[],
        invalidBlocks: string[] = [],
    ) {
        const block = await mgr.lastRemoteMinedBlock(remoteChainId);
        const lastFin = await state.getLastFinalizedBlock(remoteChainId);
        console.log(block);
        const blockNonce = Number(block.nonce.toString());
        const fin = Number(lastFin.nonce.toString());
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
        const txLen = await ctx.chain1.ledgerMgr.getLocalBlockTransactionLength(key);
        console.log('Tx len for block', key, 'is', txLen.toString());
        let tx = await ctx.chain1.ledgerMgr.getLocalBlockTransaction(key, 0); 
        await QuantumPortalUtils.stakeAndDelegate(ctx.chain1.ledgerMgr, ctx.chain1.autorityMgr, ctx.chain1.stake, '10', ctx.owner, ctx.wallets[0], ctx.signers.owner, ctx.sks[0]);
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
        const txLen = await ctx.chain1.ledgerMgr.getLocalBlockTransactionLength(key);
        console.log('Tx len for block', key, 'is', txLen.toString());
        let tx = await ctx.chain1.ledgerMgr.getLocalBlockTransaction(key, 0); 
        await QuantumPortalUtils.stakeAndDelegate(ctx.chain2.ledgerMgr, ctx.chain2.autorityMgr, ctx.chain2.stake, '10', ctx.owner, ctx.wallets[0], ctx.signers.owner, ctx.sks[0]);
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
            ctx.sks[0],
            invalid ? [nonce.toString()] : []
        );
    }

    static async mineAndFinilizeTwoToOne(ctx: PortalContext, nonce: number, invalid: boolean = false) {
        let key = (await ctx.chain2.ledgerMgr.getBlockIdx(ctx.chain1.chainId, nonce)).toString();
        let tx = await ctx.chain2.ledgerMgr.getLocalBlockTransaction(key, nonce - 1); 
        // Commenting out because stake contract is shared in this test
        await ctx.chain1.token.transfer(ctx.acc1, Wei.from('10'));
        await QuantumPortalUtils.stakeAndDelegate(ctx.chain1.ledgerMgr, ctx.chain1.autorityMgr, ctx.chain2.stake, '10', ctx.acc1, ctx.wallets[1], ctx.signers.acc1, ctx.sks[1]);
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
            ctx.sks[1],
            invalid ? [nonce.toString()] : []
        );
    }
    
    static async minedBlockHash(
        chain: number,
        nonce: number,
        mgr: QuantumPortalLedgerMgrUpgradeableTest,
    ): Promise<string | undefined> {
        const existingBlock = await mgr.minedBlockByNonce(chain, nonce);
        const block = existingBlock[0].blockHash.toString();
        return isAllZero(block) ? undefined : block;
    }

    static async stakeAndDelegate(mgr: QuantumPortalLedgerMgrUpgradeableTest,
        auth: QuantumPortalAuthorityMgrUpgradeable,
        stake: QuantumPortalStakeWithDelegateUpgradeable,
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

        await (await token.token()).connect(signer).transfer(stake, await token.amountToMachine(amount));
        await stake.connect(signer).stakeToDelegate(staker, nodeOp);
        console.log(`- Staked ${amount} for ${staker}`)
        console.log('Registering miner...');
        await mgr.connect(wallet).registerMiner({gasLimit: 2000000});

        console.log('Registering the operator: ', nodeOp, 'for validator', wallet.address)
        await auth.connect(wallet).assignOperator(nodeOp, {gasLimit: 2000000});
    }
}

export interface PortalContext extends TestContext {
    chain1: {
        chainId: number;
        ledgerMgr: QuantumPortalLedgerMgrUpgradeableTest;
        poc: QuantumPortalPocUpgradeableTest;
        token: DummyToken;
        autorityMgr: QuantumPortalAuthorityMgrUpgradeable;
        minerMgr: QuantumPortalMinerMgrUpgradeable;
        stake: QuantumPortalStakeWithDelegateUpgradeable;
        feeConverter: QuantumPortalFeeConverterDirectUpgradeable;
    },
    chain2: {
        chainId: number;
        ledgerMgr: QuantumPortalLedgerMgrUpgradeableTest;
        poc: QuantumPortalPocUpgradeableTest;
        token: DummyToken;
        autorityMgr: QuantumPortalAuthorityMgrUpgradeable;
        minerMgr: QuantumPortalMinerMgrUpgradeable;
        stake: QuantumPortalStakeWithDelegateUpgradeable;
        feeConverter: QuantumPortalFeeConverterDirectUpgradeable;
    },
}

export async function deployAll(): Promise<PortalContext> {
    console.log('Signers: ', (await ethers.getSigners()).map(s => s.address));
	const ctx = await getCtx();
    console.log('Owner address: ', ctx.owner);
    const gateFac = await ethers.getContractFactory("QuantumPortalGatewayUpgradeable");
    const gate1 = await gateFac.deploy(ZeroAddress) as unknown as QuantumPortalGatewayUpgradeable;
    await gate1.initialize(ctx.owner, ctx.owner);
    const gate2 = await gateFac.deploy(ZeroAddress) as unknown as QuantumPortalGatewayUpgradeable;
    await gate2.initialize(ctx.owner, ctx.owner);

	const mgrFac = await ethers.getContractFactory("QuantumPortalLedgerMgrUpgradeableTest");
	console.log('About to deploy the ledger managers');
    const mgr1 = await mgrFac.deploy(26000, {gasLimit: 8000000}) as unknown as QuantumPortalLedgerMgrUpgradeableTest;
    await mgr1.initialize(ctx.owner, ctx.owner, Wei.from('1'), gate1.target);
    console.log('MGR LAUNCHED', await mgr1.VERSION());
    const mgr2 = await mgrFac.deploy(2) as unknown as QuantumPortalLedgerMgrUpgradeableTest;
    await mgr2.initialize(ctx.owner, ctx.owner, Wei.from('1'), gate2.target);

    const chainId1 = 31337 // (await mgr1.realChainId()).toNumber();
    const chainId2 = 2;
    console.log(`Chain IDS: ${chainId1} / ${chainId2}`);

    console.log('Setting min stakes');
    await mgr1.updateMinerMinimumStake(Wei.from('10'));
    await mgr2.updateMinerMinimumStake(Wei.from('10'));

	const pocFac = await ethers.getContractFactory("QuantumPortalPocUpgradeableTest");
	console.log('About to deploy the pocs');
    const poc1 = await pocFac.deploy(26000) as unknown as QuantumPortalPocUpgradeableTest;
    await poc1.initialize(ctx.owner, ctx.owner, gate1.target);
    const poc2 = await pocFac.deploy(2) as unknown as QuantumPortalPocUpgradeableTest;
    await poc2.initialize(ctx.owner, ctx.owner, gate2.target);

    // By default, both test ledger mgrs use the same authority mgr.
	console.log('About to deploy the authority managers');
	const autorityMgrFac = await ethers.getContractFactory("QuantumPortalAuthorityMgrUpgradeable");
    const autorityMgr1 = await autorityMgrFac.deploy() as unknown as QuantumPortalAuthorityMgrUpgradeable;
    await autorityMgr1.initialize(mgr1.target, poc1.target, ctx.acc1, ctx.acc1, gate1.target)
    const autorityMgr2 = await autorityMgrFac.deploy() as unknown as QuantumPortalAuthorityMgrUpgradeable;
    await autorityMgr2.initialize(mgr2.target, poc2.target, ctx.acc2, ctx.acc2, gate2.target)

    console.log('Deploying some tokens');
	const tokenData = abi.encode(['address'], [ctx.owner]);
    const tok1 = await deployWithOwner(ctx, 'DummyToken', ZeroAddress, tokenData) as unknown as DummyToken;

    console.log('Deploying direc fee converter');
    const feeConverterF = await ethers.getContractFactory('QuantumPortalFeeConverterDirectUpgradeable');
    const feeConverter = await feeConverterF.deploy() as unknown as QuantumPortalFeeConverterDirectUpgradeable;
    await feeConverter.initialize(gate1.target, ctx.owner);
    await feeConverter.updateFeePerByte(Wei.from('0.001'));

    console.log('Deploying staking');
    const stake = await delpoyStake(ctx, autorityMgr1.target.toString(), ZeroAddress, tok1.target.toString());
    // const stake = await delpoyStake(ctx, FERRUM_TOKENS[ctx.chainId] || panick(`No FRM token is configured for chain ${ctx.chainId}`));
    console.log('Deploying mining mgr');
    const miningMgr1 = await deployMinerMgr(stake, poc1.target.toString(), mgr1.target.toString(), gate1.target.toString(), ctx.owner);
    const miningMgr2 = await deployMinerMgr(stake, poc2.target.toString(), mgr2.target.toString(), gate2.target.toString(), ctx.acc1); // To deploy a different contract.

    console.log(`Registering a single authority ("${ctx.wallets[0]}"`);
    await autorityMgr1.connect(ctx.signers.acc1).initializeQuorum(ctx.owner, 1, 1, 0, [ctx.wallets[0]]); 
    await autorityMgr1.connect(ctx.signers.acc1).initializeQuorum(ctx.acc1, 2, 1, 0, [ctx.wallets[1]]); 
    await autorityMgr2.connect(ctx.signers.acc2).initializeQuorum(ctx.owner, 1, 1, 0, [ctx.wallets[0]]); 
    await autorityMgr2.connect(ctx.signers.acc2).initializeQuorum(ctx.acc1, 2, 1, 0, [ctx.wallets[1]]); 

    console.log(`Settting authority mgr (${autorityMgr1.target}/${autorityMgr2.target}) and miner mgr ${miningMgr1.target} / ${miningMgr2.target} on both QP managers, and fee converter`);
    await mgr1.updateAuthorityMgr(autorityMgr1.target);
    await mgr1.updateMinerMgr(miningMgr1.target);
    await mgr1.updateFeeConvertor(feeConverter.target);
    await miningMgr1.updateRemotePeers([chainId2], [miningMgr2.target]);
    await mgr2.updateAuthorityMgr(autorityMgr2.target);
    await mgr2.updateMinerMgr(miningMgr2.target);
    await mgr2.updateFeeConvertor(feeConverter.target);
    await miningMgr2.connect(ctx.signers.acc1).updateRemotePeers([chainId1], [miningMgr1.target]);

    await poc1.setManager(mgr1.target);
    await poc1.updateFeeTarget();
    await poc1.setFeeToken(tok1.target);
    await miningMgr1.updateBaseToken(tok1.target);
    await poc2.setManager(mgr2.target);
    await poc2.updateFeeTarget();
    await poc2.setFeeToken(tok1.target);
    await miningMgr2.connect(ctx.signers.acc1).updateBaseToken(tok1.target);
    await mgr1.updateLedger(poc1.target);
    await mgr2.updateLedger(poc2.target);
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
            token: tok1,
            stake,
            feeConverter,
        }
    } as PortalContext;
}

export async function estimateGasUsingEthCall(contract: string, encodedAbiForEstimateGas: string) {
    try {
        await ethers.provider.call({
            data: encodedAbiForEstimateGas,
            to: contract,
        })
        // This should not succeed
        throw new Error('Estimate gas method call must fail, but this call succeeded')
    } catch (error: any) {
        // Handle the revert reason
        const revertReason = error.data

        // Extract the gas used from the revert reason
        if (revertReason && revertReason.startsWith("0x08c379a0")) {
            const decodedReason = ethers.AbiCoder.defaultAbiCoder().decode(['string'], '0x' + revertReason.substring(10))
            const gasUsed = Number(decodedReason[0])
            return gasUsed
        } else {
            throw error
        }
    }
}
