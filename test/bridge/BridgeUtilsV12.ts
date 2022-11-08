import { BridgePoolV12 } from "../../typechain/BridgePoolV12";
import { BridgeRemoteStaking } from "../../typechain/BridgeRemoteStaking";
import { BridgeRouterV12 } from "../../typechain/BridgeRouterV12";
import { abi, TestContext } from "../common/Utils";
import Web3 from 'web3';
import { Eip712Params, multiSigToBytes, produceSignature, signWithPrivateKey } from "../common/Eip712Utils";
import { expect } from "chai";
import { BridgeRoutingTable } from "../../typechain/BridgeRoutingTable";

export const BRIDGNE_NAME = 'FERRUM_TOKEN_BRIDGE_POOL';
export const BRIDGE_VERSION = '001.200';

export interface BridgeContext extends TestContext {
	bridge: BridgePoolV12;
	bridgeRouter: BridgeRouterV12;
	staking: BridgeRemoteStaking;
    routingTable: BridgeRoutingTable;
}

export async function setMultisigQuorums(ctx: BridgeContext) {
	// Create the governance quorum
	// Create one more quorum
	// Create a 2 sig quorum
	// Make sure qurums are all set
	const cId = ctx.owner; // Using owner addr as the quorum ID just for fun
	// await ctx.bridge.addToQuorum(ctx.wallets[0], cId, '1', 2);
	console.log(`Addint to quorum ${ctx.wallets[0]}-${cId}, ${'1'}, {2}`);
	// await ctx.bridge.addToQuorum(ctx.wallets[1], cId, '1', 2);
	console.log(`Addint to quorum ${ctx.wallets[1]}-${cId}, ${'1'}, {2}`);
	// await ctx.bridge.addToQuorum(ctx.wallets[2], ctx.acc2, '0', 1);
	// await ctx.bridge.addToQuorum(ctx.wallets[3], ctx.acc3, '101', 2);
	// await ctx.bridge.addToQuorum(ctx.wallets[4], ctx.acc3, '101', 2);
	// await ctx.bridge.addToQuorum(ctx.wallets[5], ctx.acc3, '101', 2);

	let [qrmId, groupId, minSignatures] = await ctx.bridge.quorums(cId);
	expect(qrmId).to.be.equal(cId);
	expect(groupId).to.be.equal(1);
	expect(minSignatures).to.be.equal(2);
	[qrmId, groupId, minSignatures] = await ctx.bridge.quorumSubscriptions(ctx.wallets[0]);
	expect(qrmId).to.be.equal(cId);
	expect(groupId).to.be.equal(1);
	expect(minSignatures).to.be.equal(2);
	[qrmId, groupId, minSignatures] = await ctx.bridge.quorumSubscriptions(ctx.wallets[1]);
	expect(qrmId).to.be.equal(cId);
	expect(groupId).to.be.equal(1);
	expect(minSignatures).to.be.equal(2);

	[qrmId, groupId, minSignatures] = await ctx.bridge.quorumSubscriptions(ctx.wallets[2]);
	expect(qrmId).to.be.equal(ctx.acc2);
	expect(groupId).to.be.equal(0);
	expect(minSignatures).to.be.equal(1);

	[qrmId, groupId, minSignatures] = await ctx.bridge.quorumSubscriptions(ctx.wallets[4]);
	expect(qrmId).to.be.equal(ctx.acc3);
	expect(groupId).to.be.equal(101);
	expect(minSignatures).to.be.equal(2);
}

export async function getBridgeMethodCall(
		contractName: string,
		contractVersion: string,
		chainId: number,
		bridge: string,
		methodName: string,
		args: {type: string, name: string, value: string}[], sks: string[]) {
	const web3 = new Web3();
	// console.log('We are going to bridge method call it ', args)
	const msg = produceSignature(
		web3.eth, chainId, bridge, {
			contractName: contractName,
			contractVersion: contractVersion,
			method: methodName,
			args,
		} as Eip712Params,
	);
	// console.log('About to producing msg ', msg)
	const sigs = [];
	for (const sk of sks) {
		console.log(`    About to sign with private key ${sk}`);
		const {sig, addr} = await signWithPrivateKey(sk, msg.hash!);
		sigs.push({sig, addr});
	}
    // Make sure that signatures are in the order of the signer address
    sigs.sort((s1, s2) => Buffer.from(s2.addr, 'hex') < Buffer.from(s1.addr, 'hex') ? 1 : -1);
	const fullSig = multiSigToBytes(sigs.map(s => s.sig));
	console.log('    Full signature is hash: ', msg.hash, 'sig:', fullSig);
	msg.signature = fullSig;
	return msg;
}

export async function bridgeMethodCall(
		ctx: BridgeContext,
		methodName: string,
		args: {type: string, name: string, value: string}[], sks: string[]) {
	return getBridgeMethodCall(BRIDGNE_NAME, BRIDGE_VERSION, ctx.chainId, ctx.bridge.address, methodName, args, sks);
}