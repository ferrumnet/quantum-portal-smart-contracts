import { ethers } from "hardhat";
import { abi, ZeroAddress, sleep, Wei } from "foundry-contracts/dist/test/common/Utils";
import { panick, _WETH, deployUsingDeployer, contractExists, isAllZero, distributeTestTokensIfTest } from "../../test/common/Utils";
import { QuantumPortalPoc } from "../../typechain-types/QuantumPortalPoc";
import { QuantumPortalLedgerMgr } from "../../typechain-types/QuantumPortalLedgerMgr";
import { QuantumPortalAuthorityMgr } from "../../typechain-types/QuantumPortalAuthorityMgr";
import { QuantumPortalMinerMgr } from "../../typechain-types/QuantumPortalMinerMgr";
import { QuantumPortalGateway } from "../../typechain-types/QuantumPortalGateway";
import { UniswapOracle } from "../../typechain-types/UniswapOracle";
import { loadQpDeployConfig, QpDeployConfig } from "../utils/DeployUtils";
import { Signer } from "ethers";
import { QuantumPortalFeeConverterDirect } from "../../typechain-types/QuantumPortalFeeConverterDirect";
import { QuantumPortalState } from "../../typechain-types/QuantumPortalState";
import { QuantumPortalUtils } from "../../test/quantumPortal/poc/QuantumPortalUtils";
import { QuantumPortalStakeWithDelegate } from "../../typechain-types/QuantumPortalStakeWithDelegate";
import { QuantumPortalLedgerMgrTest } from "../../typechain-types/QuantumPortalLedgerMgrTest";
import { QpErc20Token } from "../../typechain-types/QpErc20Token";
const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';

interface Ctx {
    gateway: QuantumPortalGateway;
    state: QuantumPortalState;
    poc: QuantumPortalPoc;
    mgr: QuantumPortalLedgerMgrTest;
    auth: QuantumPortalAuthorityMgr;
    miner: QuantumPortalMinerMgr;
    feeConvertor: QuantumPortalFeeConverterDirect;
    uniV2Oracle: UniswapOracle;
    stake: QuantumPortalStakeWithDelegate;
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

async function registerAll(ctx: Ctx, qpWallet: Signer) {
    console.log("Updating  miner stake");
    let updateminerstake = await ctx.mgr.connect(qpWallet).updateMinerMinimumStake(0);
    console.log(updateminerstake);

    const minerSk = '';
    const minerWallet = new ethers.Wallet(minerSk, ethers.provider);
    console.log("Sending 10 ETH to miner wallet");
    await qpWallet.sendTransaction({
        to: minerWallet.address,
        value: Wei.from('10'),
    });

    console.log("Stakign for the miner");

    console.log('Send fee to the miner wallet');
    const tokF = await ethers.getContractFactory('QpErc20Token');
    const feeT = await tokF.attach(await ctx.poc.feeToken()) as QpErc20Token;
    await feeT.connect(qpWallet).transfer(minerWallet.address, Wei.from('10'));

    console.log('QP wallet balance', await feeT.balanceOf(await qpWallet.getAddress()));

    await QuantumPortalUtils.stakeAndDelegate(
        ctx.mgr
        , ctx.stake, '1', await qpWallet.getAddress(), minerWallet.address, qpWallet, minerSk);

    console.log("Finding miners");
    let miners = await ctx.mgr.isLocalBlockReady(31337);
    console.log(miners);

    console.log(`Registering a single authority ("minerWallet"`);
    await ctx.auth.connect(qpWallet).initialize(minerWallet.address, 1, 1, 0, [minerWallet.address]); 
}

async function prep(conf: QpDeployConfig): Promise<[Ctx, Signer]> {
    const deployerWallet = !!conf.DeployerKeys.DeployerContract ? new ethers.Wallet(conf.DeployerKeys.DeployerContract, ethers.provider) : undefined;
    const qpWallet = !!conf.DeployerKeys.DeployerContract ? new ethers.Wallet(conf.DeployerKeys.Qp, ethers.provider) : undefined;
    const ownerWallet = !!conf.DeployerKeys.Owner ? new ethers.Wallet(conf.DeployerKeys.Owner, ethers.provider) : undefined;
    if (ownerWallet) {
        conf.Owner = await ownerWallet.getAddress();
    }
    console.log(`Wallets: DEPLOYER = ${deployerWallet.address}, QP = ${qpWallet.address}, OWNER_WALLET=${ownerWallet.address}`);
    console.log(`Using the following config: `, {
        ...conf,
        DeployerKeys: {},
    });

    console.log("Deployer Contract ", conf.DeployerContract);

    if (conf.DeployerContract == undefined || !(
            await (contractExists('FerrumDeployer', conf.DeployerContract)))) {
        console.log(`No deployer contract. Deploying one using ("${deployerWallet.address}")...`);
        const FerrumDep = await ethers.getContractFactory("FerrumDeployer");
        const ferrumDep = await FerrumDep.connect(deployerWallet).deploy({gasLimit: 2000000});
        logForRecord('Ferrum Deployer address', ferrumDep.address);
        conf.DeployerContract = ferrumDep.address;
        sleep(2000);
    }

    let newGateway: boolean;
    let newState: boolean;
    let newPoc: boolean;
    let newLedgerMgr: boolean;
    let newAut: boolean;
    let newStake: boolean;
    let newMinerMgr: boolean;
    let newFeeConvertor: boolean;
    let newUniV2Oracle: boolean;
    const ctx: Ctx = {} as any;
    [ctx.gateway, newGateway] = await attach(conf, conf.QuantumPortalGateway, 'QuantumPortalGateway', conf.Owner, '0x', qpWallet,
        async () => {
            console.log('Deploying gateway');
            const initData = abi.encode(['address'], [conf.WFRM]);
            const deped = await deployUsingDeployer('QuantumPortalGateway', conf.Owner, initData,
                conf.DeployerContract, conf.DeployerSalt, qpWallet) as QuantumPortalGateway;
            logForRecord('QP Gateway', deped.address);
            return deped;
        });

    [ctx.state, newState] = await attach(conf, conf.QuantumPortalState, 'QuantumPortalState', conf.Owner, '0x', qpWallet,);
    [ctx.stake,] = await attach(conf, conf.QuantumPortalStake, 'QuantumPortalStakeWithDelegate', conf.Owner, '0x', qpWallet,);
    [ctx.poc, newPoc] = await attach(conf, conf.QuantumPortalPoc, 'QuantumPortalPocImpl', conf.Owner, '0x', qpWallet,);
    [ctx.mgr, newLedgerMgr] = await attach(conf, conf.QuantumPortalLedgerMgr, 'QuantumPortalLedgerMgrImpl', conf.Owner, '0x', qpWallet,);
    const authMgrInitData = abi.encode(['address', 'address'], [ctx.poc.address, ctx.mgr.address]);
    [ctx.auth, newAut] = await attach(conf, conf.QuantumPortalAuthorityMgr, 'QuantumPortalAuthorityMgr', conf.Owner, authMgrInitData, qpWallet,);
    [ctx.miner,] = await attach(conf, conf.QuantumPortalMinerMgr, 'QuantumPortalMinerMgr', conf.Owner, '0x', qpWallet,);

    const chainId = (await ethers.provider.getNetwork()).chainId;
    ctx.chainId = chainId;
    return [ctx, qpWallet];
}

async function main(withReg: boolean) {
    const conf = loadQpDeployConfig(process.env.QP_CONFIG_FILE || DEFAULT_QP_CONFIG_FILE);
    const [ctx, qpWallet] = await prep(conf);

    if (withReg) {
        await registerAll(ctx, qpWallet);
    }

    let lastMinedBlock = await ctx.state.getLastMinedBlock(ctx.chainId);
    console.log({lastMinedBlock});
    let start_nonce = lastMinedBlock.nonce.toNumber() + 1;

    while (true) {
        let mined = await mineAndFinilizeOneToOne(ctx, start_nonce);
        if (mined) {
            start_nonce++
        }
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

    const minerWallet = new ethers.Wallet("", ethers.provider);

    const [salt, expiry, signature] = await QuantumPortalUtils.generateSignatureForMining(
        ctx.mgr,
        ctx.chainId.toString(),
        nonce.toString(),
        txs,
        minerWallet.privateKey, // Miner...
    );

    console.log('Mining block', await ctx.miner.miningStake());
    console.log('TX', JSON.stringify(txs, null, 2));
    await ctx.mgr.mineRemoteBlock(
        ctx.chainId,
        nonce.toString(),
        txs,
        salt,
        expiry,
        signature,
        // {gasLimit: 10000000},
    );
    console.log('Mined block', nonce.toString());

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
  
main(false)
	.then(() => process.exit(0))
	.catch(error => {
	  console.error(error);
	  process.exit(1);
});
