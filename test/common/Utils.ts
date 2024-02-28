import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { randomBytes } from "crypto";
import { Signer } from "ethers";
import { ethers } from "hardhat";
import { DummyToken } from "../../typechain/DummyToken";
import { DirectMinimalErc20 } from "foundry-contracts/typechain-types/DirectMinimalErc20";
import { IVersioned } from "../../typechain/IVersioned";
export const ZeroAddress = '0x' + '0'.repeat(40);
export const Salt = '0x' + '12'.repeat(32);

export const abi = ethers.utils.defaultAbiCoder;

export const _WETH: {[k: number]: string} = {
	4: '0xc778417e063141139fce010982780140aa0cd5ab',
	31337: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
	97: '0xae13d989dac2f0debff460ac112a837c89baa7cd',
	80001: '0xEb1e115f2729df2728406bcEC7b4DbBd78590300',
	137: '0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270',
}

const TEST_SKS = [
	'0x0123456789012345678901234567890123456789012345678901234567890123',
	'0x0123456789012345678901234567890123456789012345678901234567890124',
	'0x0123456789012345678901234567890123456789012345678901234567890125',
	'0x0123456789012345678901234567890123456789012345678901234567890126',
	'0x0123456789012345678901234567890123456789012345678901234567890127',
	'0x0123456789012345678901234567890123456789012345678901234567890128',
];

export interface TestContext {
	owner: string;
	acc1: string;
	acc2: string;
	acc3: string;
	acc4: string;
	acc5: string;
	signers: {
		owner: SignerWithAddress;
		acc1: SignerWithAddress;
		acc2: SignerWithAddress;
		acc3: SignerWithAddress;
		acc4: SignerWithAddress;
		acc5: SignerWithAddress;
	};
	deployer: any;
	token?: any;
	chainId: number;
	sks: string[];
	wallets: string[];
}

export class Wei {
	static from(v: string) {
		return ethers.utils.parseEther(v).toString();
	}
	static to(v: string) {
		return ethers.utils.formatEther(v);
	}
	static async toP(v: Promise<any>) {
		return Wei.to((await v).toString());
	}
	static async balance(tokAddr: string, addr: string) {
        const tf = await ethers.getContractFactory('DummyToken');
        const tok = await tf.attach(tokAddr) as DummyToken;
		const b = await tok.balanceOf(addr);
		return Wei.to(b.toString());
	}
	static async bal(tok: any, addr: string) {
		const b = await tok.balanceOf(addr);
		return Wei.to(b.toString());
	}
}

export async function getCtx(): Promise<TestContext> {
	const [owner, acc1, acc2, acc3, acc4, acc5] = await ethers.getSigners();
	const chainId = (await ethers.provider.getNetwork()).chainId;
	console.log('Using chain ID ', chainId);
	const depFac = await ethers.getContractFactory("FerrumDeployer");
	const deployer = await depFac.deploy();
	const ctx = {
		owner: owner.address,
		acc1: acc1.address, acc2: acc2.address,acc3: acc3.address,acc4: acc4.address, acc5: acc5.address,
		signers: { owner, acc1, acc2, acc3, acc4, acc5 },
		deployer,
		chainId,
		wallets: [],
		sks: [],
	} as TestContext;
	for(const sk of TEST_SKS) {
		const wallet = new ethers.Wallet(sk);
		const addr = await wallet.getAddress();
		ctx.sks.push(sk);
		ctx.wallets.push(addr);
	}
	return ctx;
}

export function sleep(time: number) {
	const p = new Promise((resolve, reject) => {
		setTimeout(() => resolve(''), time);
	});
	return p;
}

export async function deploy(ctx: TestContext, contract: string, initData: string) {
	return deployWithOwner(ctx, contract, ZeroAddress, initData);
}

export async function getGasLimit(tx: any) {
	const reci = await ethers.provider.getTransactionReceipt(tx.hash);
	return reci.gasUsed.toString();
}

export async function deployWithOwner(ctx: TestContext, contract: string, owner: string, initData: string) {
	return await deployUsingDeployer(contract, owner, initData,
		ctx.deployer.address, Salt);
}

export async function getTransactionReceipt(id: string) {
	let reci = await ethers.provider.getTransactionReceipt(id);
	for(let i=0; i<1000; i++) {
		console.log('No tx. Trying again ', i);
		await sleep(1000);
		reci = await ethers.provider.getTransactionReceipt(id);
		if (!!reci) {
			break;
		}
	}
	return reci;
}

export async function getTransactionLog(id: string, contract: any, eventName: string) {
	const reci = await getTransactionReceipt(id);
	const log = reci.logs.find(l => l.address.toLowerCase() === contract.address.toLocaleLowerCase());
	if (!reci || !log) {
		throw new Error('Could not get transaction ' + id + ' or logs were messed up. ' + (reci || ''));
	}
	if (reci) {
		let events = contract.interface.decodeEventLog(
			eventName,
			log.data,
			log.topics);
		console.log('Received event: ', events);
		if (!events) {
			throw new Error('Event not found! ' + id);
		}
		return events;
	} else {
		throw new Error('Tx not found! ' + id);
	}
}

export async function contractExists(contractName: string, contract: string) {
	const depFac = await ethers.getContractFactory(contractName);
	const deployer = await depFac.attach(contract) as IVersioned;
	console.log("COntract exsists");
    try {
		console.log(deployer);
        const isThere = await deployer.VERSION();
		console.log("isThere", isThere);
        if ( isThere && isThere.toString().length > 0) {
            return true;
        }
    } catch(e) {
		console.log("Error from exists", e);
        return false;
    }
}

export async function deployUsingDeployer(contract: string, owner: string, initData: string,
		deployerAddr: string, salt: string, siger?: Signer) {
	const contr = await ethers.getContractFactory(contract);
	const depFac = await ethers.getContractFactory("FerrumDeployer");
	const deployer = await depFac.attach(deployerAddr);
    console.log('DEPLOYADDR IS ', deployerAddr);
	console.log("owner is", owner);

	const res = siger ? await deployer.connect(siger).deployOwnable(salt, owner, initData, contr.bytecode, { gasLimit: 10000000 })
		: await deployer.deployOwnable(salt, owner, initData, contr.bytecode, { gasLimit: 10000000 });
	console.log(`Deploy tx hash: ${res.hash}`)
	const events = await getTransactionLog(res.hash, deployer, 'DeployedWithData');
	// let reci = await getTransactionReceipt(res.hash);
	// let eventAddr = '';
	// const log = reci.logs.find(l => l.address.toLowerCase() === deployer.address.toLocaleLowerCase());
	// if (!reci || !log) {
	// 	throw new Error('Could not get transaction ' + res.hash + ' or logs were messed up. ' + (reci || ''));
	// }
	// if (reci) {
	// 	let events = deployer.interface.decodeEventLog(
	// 		'DeployedWithData',
	// 		log.data,
	// 		log.topics);
	// 	console.log('Received event: ', events);
		const eventAddr = events.conAddr;
		// if (!eventAddr) {
		// 	throw new Error('Event address was not found! ' + res.hash);
		// }
	// }

	const bytecodeHash = ethers.utils.keccak256(contr.bytecode);
	const addr = await deployer.computeAddressOwnable(Salt, owner, initData, bytecodeHash);
	console.log('Deployed address ', {addr, eventAddr});
	if (eventAddr !== addr) {
		console.log('Address was diferent! Sad!')
	}

	return contr.attach(eventAddr);
}

export async function deployDummyToken(ctx: TestContext, name: string = 'DummyToken', owner: string = ZeroAddress) {
	const abiCoder = ethers.utils.defaultAbiCoder;
	var initData = abiCoder.encode(['address'], [ctx.owner]);
	const tok = await deployWithOwner(ctx, name, owner, initData);
	if (!ctx.token) {
		ctx.token = tok;
	}
	return tok;
}

export async function throws(fun: Promise<any>, msg: string) {
	try {
		await fun;
		expect(false).to.be.true(`Expected to throw "${msg}" but went through as if nothing is wrong`);
	} catch (e) {
		expect((e as any).toString()).to.contain(msg, `Expected to containt "${msg}" but was ${e}`);
	}
}

export async function validateBalances(tok: any, bals: [string, string][], prefix: string) {
	for(const item of bals) {
		const [address, expected] = item;
		const actual = await Wei.bal(tok, address);
		console.log(`${prefix} - balance for ${address}: ${actual}`);
	}
}

export function panick(msg: string): any {
	throw new Error('Panick! ' + msg);
}

export function tomorrow(): number {
	return Math.round(Date.now() / 1000) + 3600 * 24;
}

export async function setMiniMultiSigQuorum(ctx: TestContext, contract:  any) {
	// Create a single quorum
	const cId = ctx.owner; // Using owner addr as the quorum ID just for fun
	await contract.initialize(ctx.owner, '1', '1', '0', [ctx.wallets[0]]);
	// await contract.addToQuorum(ctx.wallets[0], cId, '1', 1);
	console.log(`Adding to quorum ${ctx.wallets[0]}-${cId}, ${'1'}, 1}`);

	let [qrmId, groupId, minSignatures] = await contract.quorums(cId);
	expect(qrmId).to.be.equal(cId);
	expect(groupId).to.be.equal(1);
	expect(minSignatures).to.be.equal(1);
	[qrmId, groupId, minSignatures] = await contract.quorumSubscriptions(ctx.wallets[0]);
	expect(qrmId).to.be.equal(cId);
	expect(groupId).to.be.equal(1);
	expect(minSignatures).to.be.equal(1);
}

export async function setMultisigQuorum(qId: string, _groupId: string, minSig: string, initAddresses: string[], contract: any) {
	// Create a quorum
	await contract.initialize(qId, _groupId, minSig, '0', initAddresses);
	// await contract.addToQuorum(ctx.wallets[0], cId, '1', 1);
	console.log(`Adding to quorum ${qId}, ${initAddresses.length} addresses`);

	let [qrmId, groupId, minSignatures] = await contract.quorums(qId);
	expect(qrmId).to.be.equal(qId);
	expect(groupId).to.be.equal(Number(_groupId));
	expect(minSignatures).to.be.equal(Number(minSig));
	[qrmId, groupId, minSignatures] = await contract.quorumSubscriptions(initAddresses[0]);
	expect(qrmId).to.be.equal(qId);
	expect(groupId).to.be.equal(Number(_groupId));
	expect(minSignatures).to.be.equal(Number(minSig));
}

export function isAllZero(hex: string) {
    return (hex || '').replace(/0|x|X/g,'').length == 0;
}

export function seed0x() {
    return '0x' + randomBytes(32).toString('hex');
}

export function expiryInFuture() {
    return Math.round(Date.now() / 1000) + 3600 * 100;
}

export async function distributeTestTokensIfTest(targets: string[], amount: string) {
	if (process.env.LOCAL_NODE) {
		const [owner] = await ethers.getSigners();
		const tokF = await ethers.getContractFactory('DirectMinimalErc20');
		const tok = await tokF.deploy() as DirectMinimalErc20;
		await tok.init(owner.address, 'Test Token', 'TST', Wei.from('1000000000'));;
		console.log(`Deployed a token at ${tok.address}`);
		for(let i=0; i<targets.length; i++) {
			if (targets[i]) {
				console.log(`Sending ${amount} ETH to ${targets[i]}`);
				await owner.sendTransaction({
					to: targets[i],
					value: Wei.from(amount),
				});
				await tok.transfer(targets[i], Wei.from('10000'));
			}
		}
	}
}