import { ethers } from "hardhat";
import { abi, ZeroAddress, sleep, Wei } from "foundry-contracts/dist/test/common/Utils";
import { panick, _WETH, deployUsingDeployer, contractExists, isAllZero, distributeTestTokensIfTest } from "../../../test/common/Utils";
import { QuantumPortalPoc } from "../../../typechain/QuantumPortalPoc";
import { QuantumPortalLedgerMgr } from "../../../typechain/QuantumPortalLedgerMgr";
import { QuantumPortalAuthorityMgr } from "../../../typechain/QuantumPortalAuthorityMgr";
import { QuantumPortalStake } from "../../../typechain/QuantumPortalStakeWithDelegate";
import { QuantumPortalMinerMgr } from "../../../typechain/QuantumPortalMinerMgr";
import { QuantumPortalGateway } from "../../../typechain/QuantumPortalGateway";
import { UniswapOracle } from "../../../typechain/UniswapOracle";
import { loadQpDeployConfig, QpDeployConfig } from "../../utils/DeployUtils";
import { Signer, getDefaultProvider } from "ethers";
import { QuantumPortalFeeConverterDirect } from "../../../typechain-types/QuantumPortalFeeConverterDirect";
import { QuantumPortalState } from "../../../typechain-types/QuantumPortalState";
import { TEST_MNEMONICS } from "../../../test/common/TestAccounts";
import { QuantumPortalUtils } from "../../../test/quantumPortal/poc/QuantumPortalUtils";
const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';

export interface PortalContext {
    chain1: {
        chainId: number;
        gateway: QuantumPortalGateway;
        ledgerMgr: QuantumPortalLedgerMgr;
        poc: QuantumPortalPoc;
        autorityMgr: QuantumPortalAuthorityMgr;
        state: QuantumPortalState,
        minerMgr: QuantumPortalMinerMgr;
        stake: QuantumPortalStake;
        feeConverter: QuantumPortalFeeConverterDirect;
    },
    chain2: {
        chainId: number;
        gateway: QuantumPortalGateway;
        ledgerMgr: QuantumPortalLedgerMgr;
        poc: QuantumPortalPoc;
        autorityMgr: QuantumPortalAuthorityMgr;
        state: QuantumPortalState,
        minerMgr: QuantumPortalMinerMgr;
        stake: QuantumPortalStake;
        feeConverter: QuantumPortalFeeConverterDirect;
    },
}


interface Ctx {
    gateway: QuantumPortalGateway;
    state: QuantumPortalState;
    poc: QuantumPortalPoc;
    mgr: QuantumPortalLedgerMgr;
    auth: QuantumPortalAuthorityMgr;
    miner: QuantumPortalMinerMgr;
    feeConvertor: QuantumPortalFeeConverterDirect;
    uniV2Oracle: UniswapOracle;
    stake: QuantumPortalStake;
    chainId: number;
}

async function attach(
    conf: QpDeployConfig,
    contractAddress: any,
    contractName: string,
    owner: string,
    initData: string,
    signer: Signer,
    deployer?: () => Promise<any>,
    ): Promise<[any, boolean]> {
    console.log(`${contractName} exists on `, contractAddress);
	const pocF = await ethers.getContractFactory(contractName);
    return [pocF.attach(contractAddress) as any, false];
}

function logForRecord(name: string, addr: string) {
    console.log('*'.repeat(80));
    console.log('*'.repeat(80));
    console.log(`${name}: "${addr}"`);
    console.log('*'.repeat(80));
    console.log('*'.repeat(80));
}

async function prep(conf: QpDeployConfig) {
    // const deployerWallet = !!conf.DeployerKeys.DeployerContract ? new ethers.Wallet(conf.DeployerKeys.DeployerContract, ethers.provider) : undefined;
    const qpWallet = new ethers.Wallet("cb6df9de1efca7a3998a8ead4e02159d5fa99c3e0d4fd6432667390bb4726854", ethers.provider);
    // const ownerWallet = !!conf.DeployerKeys.Owner ? new ethers.Wallet(conf.DeployerKeys.Owner, ethers.provider) : undefined;
    // await distributeTestTokensIfTest([deployerWallet.address, qpWallet.address, ownerWallet?.address], '10');
    // if (ownerWallet) {
    //     conf.Owner = await ownerWallet.getAddress();
    // }
    // console.log(`Wallets: DEPLOYER = ${deployerWallet.address}, QP = ${qpWallet.address}, OWNER_WALLET=${ownerWallet.address}`);
    // console.log(`Using the following config: `, {
    //     ...conf,
    //     DeployerKeys: {},
    // });

    // console.log("Deployer Contract ", conf.DeployerContract);

    // if (conf.DeployerContract == undefined || !(
    //         await (contractExists('FerrumDeployer', conf.DeployerContract)))) {
    //     console.log(`No deployer contract. Deploying one using ("${deployerWallet.address}")...`);
    //     const FerrumDep = await ethers.getContractFactory("FerrumDeployer");
    //     const ferrumDep = await FerrumDep.connect(deployerWallet).deploy({gasLimit: 2000000});
    //     logForRecord('Ferrum Deployer address', ferrumDep.address);
    //     conf.DeployerContract = ferrumDep.address;
    //     sleep(2000);
    // }

    let newGateway: boolean;
    let newState: boolean;
    let newPoc: boolean;
    let newLedgerMgr: boolean;
    let newAut: boolean;
    let newStake: boolean;
    let newMinerMgr: boolean;
    let newFeeConvertor: boolean;
    let newUniV2Oracle: boolean;
    const ctx: PortalContext = {} as any;
    [ctx.chain1.gateway, newGateway] = await attach(conf, conf.QuantumPortalGateway, 'QuantumPortalGateway', conf.Owner, '0x', qpWallet,
        async () => {
            console.log('Deploying gateway');
            const initData = abi.encode(['address'], [conf.WFRM]);
            const deped = await deployUsingDeployer('QuantumPortalGateway', conf.Owner, initData,
                conf.DeployerContract, conf.DeployerSalt, qpWallet) as QuantumPortalGateway;
            logForRecord('QP Gateway', deped.address);
            return deped;
        });

    [ctx.chain1.state, newState] = await attach(conf, conf.QuantumPortalState, 'QuantumPortalState', conf.Owner, '0x', qpWallet,);
    [ctx.chain1.poc, newPoc] = await attach(conf, conf.QuantumPortalPoc, 'QuantumPortalPocImpl', conf.Owner, '0x', qpWallet,);
    [ctx.chain1.ledgerMgr, newLedgerMgr] = await attach(conf, conf.QuantumPortalLedgerMgr, 'QuantumPortalLedgerMgrImpl', conf.Owner, '0x', qpWallet,);
    // const authMgrInitData = abi.encode(['address', 'address'], [ctx.chain1.poc.address,ctx.chain1.ledgerMgr.address]);
    // [ctx.chain1.autorityMgr, newAut] = await attach(conf, conf.QuantumPortalAuthorityMgr, 'QuantumPortalAuthorityMgr', conf.Owner, authMgrInitData, qpWallet,);

    [ctx.chain2.gateway, newGateway] = await attach(conf, conf.QuantumPortalGateway, 'QuantumPortalGateway', conf.Owner, '0x', qpWallet,
        async () => {
            console.log('Deploying gateway');
            const initData = abi.encode(['address'], [conf.WFRM]);
            const deped = await deployUsingDeployer('QuantumPortalGateway', conf.Owner, initData,
                conf.DeployerContract, conf.DeployerSalt, qpWallet) as QuantumPortalGateway;
            logForRecord('QP Gateway', deped.address);
            return deped;
        });

    [ctx.chain2.state, newState] = await attach(conf, conf.QuantumPortalState, 'QuantumPortalState', conf.Owner, '0x', qpWallet,);
    [ctx.chain2.poc, newPoc] = await attach(conf, conf.QuantumPortalPoc, 'QuantumPortalPocImpl', conf.Owner, '0x', qpWallet,);
    [ctx.chain2.ledgerMgr, newLedgerMgr] = await attach(conf, conf.QuantumPortalLedgerMgr, 'QuantumPortalLedgerMgrImpl', conf.Owner, '0x', qpWallet,);
    // const authMgrInitData = abi.encode(['address', 'address'], [ctx.poc.address, ctx.mgr.address]);
    // [ctx.chain2.autorityMgr, newAut] = await attach(conf, conf.QuantumPortalAuthorityMgr, 'QuantumPortalAuthorityMgr', conf.Owner, authMgrInitData, qpWallet,);

    const chainId = (await ethers.provider.getNetwork()).chainId;
    ctx.chain1.chainId = chainId;
    return ctx;
}

async function main() {
    const conf = loadQpDeployConfig(process.env.QP_CONFIG_FILE || DEFAULT_QP_CONFIG_FILE);
    const ctx = await prep(conf);

    let lastMinedBlock = await ctx.state.getLastMinedBlock(ctx.chainId);
    console.log({lastMinedBlock});
    let start_nonce = lastMinedBlock.nonce.toNumber() + 1;

    while (true) {
        let mined = await mineAndFinilizeOneToTwo(ctx, start_nonce);
        // if (mined) {
        //     start_nonce++
        // }
        await new Promise(resolve => setTimeout(resolve, 8000));
    }  
}

async function mineAndFinilizeOneToOne(ctx: Ctx, nonce: number, invalid: boolean = false) {
    console.log("Prepping to mine with index", nonce);
    let isBlRead = await ctx.mgr.isLocalBlockReady(ctx.chainId);
    isBlRead = await ctx.mgr.isLocalBlockReady(ctx.chainId);
    console.log('Local block is ready? ', isBlRead);
    

    let key = (await ctx.mgr.getBlockIdx(ctx.chainId, nonce)).toString();
    if (key === undefined) return false;

    let lastMinedBlock = await ctx.state.getLastMinedBlock(ctx.chainId);
    console.log({lastMinedBlock});

    const txLen = await ctx.state.getLocalBlockTransactionLength(key);

    if (txLen.isZero()) return false;

    console.log('Tx len for block', key, 'is', txLen.toString());
    let tx = await ctx.state.getLocalBlockTransaction(key, 0); 

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


    const minerWallet = new ethers.Wallet("cb6df9de1efca7a3998a8ead4e02159d5fa99c3e0d4fd6432667390bb4726854", ethers.provider);
    const [salt, expiry, signature] = await QuantumPortalUtils.generateSignatureForMining(
        ctx.mgr,
        ctx.chainId.toString(),
        nonce.toString(),
        txs,
        minerWallet.privateKey, // Miner...
    );
    await ctx.mgr.mineRemoteBlock(
        ctx.chainId,
        nonce.toString(),
        txs,
        salt,
        expiry,
        signature,
    );

    await new Promise(resolve => setTimeout(resolve, 12000));

    console.log('Now finalizing on chain1', invalid ? [nonce.toString()] : []);
    await QuantumPortalUtils.finalize(
        ctx.chainId,
        ctx.mgr,
        ctx.state,
        minerWallet.privateKey,
        invalid ? [nonce.toString()] : []
    );

    return true;
}

async function mineAndFinilizeOneToTwo(ctx: PortalContext, nonce: number, invalid: boolean = false) {
    let isBlRead = await ctx.chain1.ledgerMgr.isLocalBlockReady(ctx.chain2.chainId);
    if (!isBlRead) {
        //await advanceTimeAndBlock(10000);
        console.log('Local block was not ready... Advancing time.');
    }
    isBlRead = await ctx.chain1.ledgerMgr.isLocalBlockReady(ctx.chain2.chainId);
    console.log('Local block is ready? ', isBlRead);

    let key = (await ctx.chain1.ledgerMgr.getBlockIdx(ctx.chain2.chainId, nonce)).toString();
    const txLen = await ctx.chain1.state.getLocalBlockTransactionLength(key);
    console.log('Tx len for block', key, 'is', txLen.toString());
    let tx = await ctx.chain1.state.getLocalBlockTransaction(key, 0); 
    //await QuantumPortalUtils.stakeAndDelegate(ctx.chain2.ledgerMgr, ctx.chain2.stake, '10', ctx.owner, ctx.wallets[0], ctx.signers.owner, ctx.sks[0]);
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
    
    const minerWallet = new ethers.Wallet("1f3bacb4212b04d1b8c3362207e5086939cf773f02cc0d966d945edb7214b57c", ethers.provider);
    const [salt, expiry, signature] = await QuantumPortalUtils.generateSignatureForMining(
        ctx.chain2.ledgerMgr,
        ctx.chain1.chainId.toString(),
        nonce.toString(),
        txs,
        minerWallet.privateKey, // Miner...
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
        minerWallet.privateKey,
        invalid ? [nonce.toString()] : []
    );
}
  
main()
	.then(() => process.exit(0))
	.catch(error => {
	  console.error(error);
	  process.exit(1);
});