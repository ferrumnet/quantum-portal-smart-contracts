import { ethers } from "hardhat";
import { abi, ZeroAddress } from "foundry-contracts/dist/test/common/Utils";
import { panick, _WETH, deployUsingDeployer, contractExists, isAllZero, distributeTestTokensIfTest } from "../../../test/common/Utils";
import { QuantumPortalPoc } from "../../../typechain/QuantumPortalPoc";
import { QuantumPortalLedgerMgr } from "../../../typechain/QuantumPortalLedgerMgr";
import { QuantumPortalAuthorityMgr } from "../../../typechain/QuantumPortalAuthorityMgr";
import { QuantumPortalStake } from "../../../typechain/QuantumPortalStake";
import { QuantumPortalMinerMgr } from "../../../typechain/QuantumPortalMinerMgr";
import { QuantumPortalGateway } from "../../../typechain/QuantumPortalGateway";
import { UniswapOracle } from "../../../typechain/UniswapOracle";
import { loadQpDeployConfig, QpDeployConfig } from "../../utils/DeployUtils";
import { Signer } from "ethers";
import { QuantumPortalFeeConverterDirect } from "../../../typechain-types/QuantumPortalFeeConverterDirect";
import { QuantumPortalState } from "../../../typechain-types/QuantumPortalState";

const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';

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
}

async function deployOrAttach(
    conf: QpDeployConfig,
    contractAddress: any,
    contractName: string,
    owner: string,
    initData: string,
    signer: Signer,
    deployer?: () => Promise<any>,
    ): Promise<[any, boolean]> {
    if (contractAddress &&
        await (contractExists(contractName, contractAddress))) {
        console.log(`${contractName} exists on `, contractAddress);
	    const pocF = await ethers.getContractFactory(contractName);
        return [pocF.attach(contractAddress) as any, false];
    } else {
        if (!!deployer) {
            const deped = await deployer();
            return [deped, true];
        } else {
            console.log(`Deploying ${contractName} with owner=${owner}, initData: ${initData} using deployer: ${conf.DeployerContract}, salt: ${conf.DeployerSalt}`);
            const deped = await deployUsingDeployer(contractName, owner, initData,
                conf.DeployerContract, conf.DeployerSalt, signer) as QuantumPortalPoc;
            logForRecord(contractName, deped.address);
            return [deped, true];
        }
    }
}

function logForRecord(name: string, addr: string) {
    console.log('*'.repeat(80));
    console.log('*'.repeat(80));
    console.log(`${name}: "${addr}"`);
    console.log('*'.repeat(80));
    console.log('*'.repeat(80));
}

async function prep(conf: QpDeployConfig) {
    const deployerWallet = !!conf.DeployerKeys.DeployerContract ? new ethers.Wallet(conf.DeployerKeys.DeployerContract, ethers.provider) : undefined;
    const qpWallet = !!conf.DeployerKeys.DeployerContract ? new ethers.Wallet(conf.DeployerKeys.Qp, ethers.provider) : undefined;
    const ownerWallet = !!conf.DeployerKeys.Owner ? new ethers.Wallet(conf.DeployerKeys.Owner, ethers.provider) : undefined;
    await distributeTestTokensIfTest([deployerWallet.address, qpWallet.address, ownerWallet?.address], '10');
    if (ownerWallet) {
        conf.Owner = await ownerWallet.getAddress();
    }
    console.log(`Using the following config: `, {
        ...conf,
        DeployerKeys: {},
    });

    if (!conf.DeployerContract || !(
            await (contractExists('FerrumDeployer', conf.DeployerContract)))) {
        console.log(`No deployer contract. Deploying one using ("${deployerWallet.address}")...`);
        const FerrumDep = await ethers.getContractFactory("FerrumDeployer");
        const ferrumDep = await FerrumDep.connect(deployerWallet).deploy();
        logForRecord('Ferrum Deployer address', ferrumDep.address);
        conf.DeployerContract = ferrumDep.address;
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
    [ctx.gateway, newGateway] = await deployOrAttach(conf, conf.QuantumPortalGateway, 'QuantumPortalGateway', conf.Owner, '0x', qpWallet,
        async () => {
            console.log('Deploying gateway');
            const initData = abi.encode(['address'], [conf.WFRM]);
            const deped = await deployUsingDeployer('QuantumPortalGateway', conf.Owner, initData,
                conf.DeployerContract, conf.DeployerSalt, qpWallet) as QuantumPortalGateway;
            logForRecord('QP Gateway', deped.address);
            return deped;
        });

    [ctx.state, newState] = await deployOrAttach(conf, conf.QuantumPortalState, 'QuantumPortalState', conf.Owner, '0x', qpWallet,);
    [ctx.poc, newPoc] = await deployOrAttach(conf, conf.QuantumPortalPoc, 'QuantumPortalPocImpl', conf.Owner, '0x', qpWallet,);
    [ctx.mgr, newLedgerMgr] = await deployOrAttach(conf, conf.QuantumPortalLedgerMgr, 'QuantumPortalLedgerMgrImpl', conf.Owner, '0x', qpWallet,);
    [ctx.auth, newAut] = await deployOrAttach(conf, conf.QuantumPortalAuthorityMgr, 'QuantumPortalAuthorityMgr', conf.Owner, '0x', qpWallet,);

    const chainId = (await ethers.provider.getNetwork()).chainId;
    const weAreOnFrmChain = true; // conf.WETH[chainId] === conf.WFRM;
    if (weAreOnFrmChain) {
        [ctx.feeConvertor, newFeeConvertor] = await deployOrAttach(
            conf, conf.QuantumPortalFeeConvertorDirect, 'QuantumPortalFeeConverterDirect', conf.Owner, '0x', qpWallet,);
    } else {
        const oracleInit = abi.encode(conf.UniV2Factory[chainId] || panick(`No UniV2Factory is configured for chain "${chainId}"`), ['address']);
        [ctx.uniV2Oracle, newUniV2Oracle] = await deployOrAttach(conf, conf.UniswapOracle, 'UniswapOracle', ZeroAddress, oracleInit, qpWallet,);
        if (newUniV2Oracle) {
            conf.QuantumPortalFeeConvertor = undefined;
        }
        const feeConvertorInits = abi.encode(
            ['address', 'address', 'address'],
            [conf.WETH[chainId] || panick(`No WETH configured for chain "${chainId}"`), conf.WFRM, ctx.uniV2Oracle.address]);
        [ctx.feeConvertor, newFeeConvertor] = await deployOrAttach(
            conf, conf.QuantumPortalFeeConvertor, 'QuantumPortalFeeConverter', conf.Owner, feeConvertorInits, qpWallet,);
    }

    let stakeToken = conf.FRM[chainId] || panick(`No stake token address for chain ${chainId}`);
    const stakeInitData = abi.encode(['address', 'address'], [stakeToken, ctx.auth.address]);
    [ctx.stake, newStake] = await deployOrAttach(conf, conf.QuantumPortalStake, 'QuantumPortalStake', conf.Owner, stakeInitData, qpWallet,);
    if (newStake) {
        console.log('New stake. Clearing the miner mgr');
        conf.QuantumPortalMinerMgr = undefined;
    }

    const minerInitData = abi.encode(['address'], [ctx.stake.address]);
    [ctx.miner, newMinerMgr] = await deployOrAttach(conf, conf.QuantumPortalMinerMgr, 'QuantumPortalMinerMgr', conf.Owner, minerInitData, qpWallet,) as 
        [QuantumPortalMinerMgr, boolean];

    console.log('Now updating dependencies...');
    if (newLedgerMgr || newPoc) {
        console.log('New POC. Updating ledgerMgr');
        await ctx.mgr.connect(qpWallet).updateLedger(ctx.poc.address);
        await ctx.poc.connect(qpWallet).setManager(ctx.mgr.addr, ctx.state.address);

    }
    if (newLedgerMgr || newMinerMgr) {
        console.log('New miner mgr. Updating ledgerMgr');
        await ctx.mgr.connect(qpWallet).updateMinerMgr(ctx.miner.address);
        console.log('Setting min stake');
        if (conf.QuantumPortalMinStake) {
            await ctx.mgr.connect(qpWallet).updateMinerMinimumStake(conf.QuantumPortalMinStake);
        }
    }
    if (newLedgerMgr || newAut) {
        console.log('New auth mgr. Updating ledgerMgr');
        await ctx.mgr.connect(qpWallet).updateAuthorityMgr(ctx.auth.address);
        await ctx.auth.connect(qpWallet).updateMgr(ctx.mgr.address);
    }
    if (newLedgerMgr || newFeeConvertor) {
        console.log('New fee convertor. Updating ledgerMgr');
        await ctx.mgr.connect(qpWallet).updateFeeConvertor(ctx.feeConvertor.address);
        if (conf.DirectFee?.feePerByte) {
            await ctx.feeConvertor.connect(qpWallet).updateFeePerByte(conf.DirectFee.feePerByte);
        }
    }
    if (newPoc || newLedgerMgr || newMinerMgr) {
        console.log('Initializing minerMgr');
        await ctx.miner.connect(qpWallet).initServer(ctx.poc.address, ctx.mgr.address, stakeToken);
    }
    if (newState) {
        console.log('Updating state on ledgerMgr and Poc');
        await ctx.mgr.connect(qpWallet).updateState(ctx.state.address);
        await ctx.poc.connect(qpWallet).setManager(ctx.mgr.addr, ctx.state.address);
    }
    if (newPoc || newMinerMgr) {
        console.log('Updating the fee target');
        await ctx.poc.connect(qpWallet).setFeeTarget(ctx.miner.address);
    }
    console.log('Upgrade gateway', ctx.gateway.address);
    if (newPoc || newLedgerMgr || newStake || newGateway) {
        console.log('Updating gateway')
        await ctx.gateway.connect(qpWallet).upgrade(ctx.poc.address, ctx.mgr.address, ctx.stake.address, { from: conf.Owner });
    }

    return ctx;
}

async function main() {
    const conf = loadQpDeployConfig(process.env.QP_CONFIG_FILE || DEFAULT_QP_CONFIG_FILE);
    const ctx = await prep(conf);
    // await configure(ctx);
}
  
main()
	.then(() => process.exit(0))
	.catch(error => {
	  console.error(error);
	  process.exit(1);
});
