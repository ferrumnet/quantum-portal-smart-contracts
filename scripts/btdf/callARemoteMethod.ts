import { ethers } from "hardhat";
import { QpDeployConfig, loadQpDeployConfig } from "../utils/DeployUtils";
import { QpErc20Token } from "../../typechain-types/QpErc20Token";
import { TokenFactory } from "../../typechain-types/TokenFactory";
import { Wei, abi, expiryInFuture } from "../../test/common/Utils";
import { randomSalt } from "foundry-contracts/dist/test/common/Eip712Utils";
import { ZeroAddress } from "foundry-contracts/dist/test/common/Utils";
import { QuantumPortalPocTest } from "../../typechain-types/QuantumPortalPocTest";
const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';
const chainId = 43113;

async function upgradeBtc(conf: QpDeployConfig) {
    const chainId = 43113;
    const newBtc = '0xca074f82f10431DFc42237F3d6B1CCbC2265f390';
	const [owner, acc1, acc2, acc3, acc4, acc5] = await ethers.getSigners();
    const facF = await ethers.getContractFactory('TokenFactory');
    if (!conf.BTFDTokenDeployer) { throw new Error('BTFDTokenDeployer required');}
    const fac = await facF.attach(conf.BTFDTokenDeployer) as TokenFactory;

    await fac.upgradeImplementations(await fac.runeImplementation(), newBtc, ZeroAddress);
}

async function inspect(conf: QpDeployConfig) {
    const pocF = await ethers.getContractFactory('QuantumPortalPocTest');
    const poc = await pocF.attach(conf.QuantumPortalPoc) as QuantumPortalPocTest;

    const feeTok = conf.FRM[chainId];
    await poc.setFeeToken(feeTok);
    
    console.log('FEE:', conf.FRM[chainId], await poc.feeToken());

    const tokF = await ethers.getContractFactory('QpErc20Token');
    const feeT = await tokF.attach(feeTok) as QpErc20Token;
    console.log('Fee', await feeT.symbol());
}

async function deployFeeToken(conf: QpDeployConfig) {
    const tokF = await ethers.getContractFactory('DummyERC20');
    const tok = await tokF.deploy({gasLimit: 10000000});
    console.log('Deplooyed fee token to: ', tok.address);

    const pocF = await ethers.getContractFactory('QuantumPortalPocTest');
    const poc = await pocF.attach(conf.QuantumPortalPoc) as QuantumPortalPocTest;
    await poc.setFeeToken(tok.address);
}

async function prep(conf: QpDeployConfig) {
	const [owner, acc1, acc2, acc3, acc4, acc5] = await ethers.getSigners();
    const facF = await ethers.getContractFactory('TokenFactory');
    if (!conf.BTFDTokenDeployer) { throw new Error('BTFDTokenDeployer required');}
    const fac = await facF.attach(conf.BTFDTokenDeployer) as TokenFactory;

    // Make sure the implementations are there
    console.log(`runeImplementation: ${await fac.runeImplementation()}`);
    console.log(`runeBeacon: ${await fac.runeBeacon()}`);
    console.log(`btcImplementation: ${await fac.btcImplementation()}`);
    console.log(`btcBeacon: ${await fac.btcBeacon()}`);
    console.log(`btc: ${await fac.btc()}`);

    // Send some gas to the BTC contract
    const tokF = await ethers.getContractFactory('QpErc20Token');
    const feeT = await tokF.attach(conf.FRM[chainId]) as QpErc20Token;
    await feeT.transfer(await fac.btc(), Wei.from('10'));

    const btc = await tokF.attach(await fac.btc()) as QpErc20Token;

    const timestamp = expiryInFuture(); // Just some timestamp for the btc tx
    console.log('Minting some BTC');
    await btc.multiTransfer([], [], [owner.address], [Wei.from('10')], 99,
            randomSalt(), timestamp, '0x'); 

    console.log('Balance', await btc.balanceOf(owner.address));

    const methodCall = btc.interface.encodeFunctionData('remoteTransfer');
    console.log('METHOD CALL IS:', methodCall);
        // Send 1 BTC to acc2, with 3 fee.
    const remoteCall = abi.encode(['uint64', 'address', 'address', 'bytes', 'uint'],
            [chainId, acc2.address, btc.address, methodCall, Wei.from('3')]);

    console.log('Multitransger with remoteCall');
    await btc.multiTransfer([owner.address], [Wei.from('1')], [conf.QuantumPortalBtcWallet], [Wei.from('1')], 100,
            randomSalt() /*txId*/, timestamp, remoteCall, {gasLimit: 10000000});
    console.log('Completed');

    // console.log('NEW BALANCE', await btc.balanceOf(acc2.address));
}

async function main() {
    console.log('Make sure to deplooy QP, then deploy BTFD')
    const conf = loadQpDeployConfig(process.env.QP_CONFIG_FILE || DEFAULT_QP_CONFIG_FILE);
    await prep(conf);
    // await inspect(conf);
    // await deployFeeToken(conf);
    // await upgradeBtc(conf);
}

main()
	.then(() => process.exit(0))
	.catch(error => {
	  console.error(error);
	  process.exit(1);
});

