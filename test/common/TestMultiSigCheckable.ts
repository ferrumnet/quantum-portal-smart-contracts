// import { expect } from "chai";
// import { ethers } from "hardhat";
// import { deployWithOwner, expiryInFuture, getCtx, TestContext, throws } from "./Utils";
// import { TestMultiSigCheckable } from '../../typechain-types/TestMultiSigCheckable';
// import { randomSalt, getBridgeMethodCall } from "./Eip712Utils";

// interface MutliSigContext extends TestContext {
//     multi: TestMultiSigCheckable;
// }

// async function deployAll(): Promise<MutliSigContext> {
// 	const ctx = await getCtx();
// 	console.log('About to deploy the multi-sig');
// 	const multi = await deployWithOwner(ctx, 'TestMultiSigCheckable', ctx.owner, '0x') as TestMultiSigCheckable;
// 	console.log('Deployed the multisig...', multi.address);

// 	return {...ctx, multi } as MutliSigContext;
// }

// export async function multiSigMethodCall(
// 		ctx: MutliSigContext,
// 		methodName: string,
// 		args: {type: string, name: string, value: string}[], sks: string[]) {
// 	const name = "TEST_MULTI_SIG_CHECKABLE";
// 	const version = "1.0.0";
// 	return getBridgeMethodCall(
// 		name, version, ctx.chainId, ctx.multi.address, methodName, args, sks);
// }

// async function _it(a: any, b: any) {};

// describe('Covering multisig checkable issues', function() {
//     it('Quorum cannot add user to other quorums', async function() {
//         const ctx = await deployAll();
//         const q1 = '0x0000000000000000000000000000000000000001';
//         const q2 = '0x0000000000000000000000000000000000000002';

//         console.log(`Initializing quorum q1 "${q1}" - with user "${ctx.wallets[1]}"`);
//         await ctx.multi.initialize(q1, 1001, 1, 0, [ctx.wallets[1]]);
//         console.log(`Initializing quorum q2 "${q2}" - with user "${ctx.wallets[2]}"`);
//         await ctx.multi.initialize(q2, 1002, 1, 0, [ctx.wallets[2]]);

//         console.log('Both quorums are created');

//         console.log('Add user to q1 from q1');
//         let salt = randomSalt();
//         let expiry = expiryInFuture().toString();

//         let multiSig = await multiSigMethodCall(
// 			ctx, 'AddToQuorum',
// 			[
// 				{ type: 'address', name: '_address', value: ctx.wallets[3] },
// 				{ type: 'address', name: 'quorumId', value: q1 },
//                 { type: 'bytes32', name:'salt', value: salt},
// 				{ type: 'uint64', name: 'expiry', value: expiry },
// 			]
// 			, [ctx.sks[1]]);
//         await ctx.multi.addToQuorum(ctx.wallets[3], q1, salt, expiry, multiSig.signature);
//         console.log('User from q1 could add users to q1');

//         salt = randomSalt();
//         multiSig = await multiSigMethodCall(
// 			ctx, 'AddToQuorum',
// 			[
// 				{ type: 'address', name: '_address', value: ctx.wallets[4] },
// 				{ type: 'address', name: 'quorumId', value: q2 },
//                 { type: 'bytes32', name:'salt', value: salt},
// 				{ type: 'uint64', name: 'expiry', value: expiry },
// 			]
// 			, [ctx.sks[1]]);
//         await throws(ctx.multi.addToQuorum(ctx.wallets[4], q2, salt, expiry, multiSig.signature),
//             'MSC: invalid groupId for signer');
//     });

//     it('Only owner can add user to other quorums', async function() {
//         const ctx = await deployAll();
//         const q0 = '0x0000000000000000000000000000000000000009';
//         const q1 = '0x0000000000000000000000000000000000000001';
//         const q2 = '0x0000000000000000000000000000000000000002';

//         console.log(`Initializing quorum q0 "${q0}" - with user "${ctx.wallets[1]}"`);
//         await ctx.multi.initialize(q0, 15, 1, 0, [ctx.wallets[1]]);

//         console.log(`Initializing quorum q1 "${q1}" - with user "${ctx.wallets[2]}"`);
//         await ctx.multi.initialize(q1, 1001, 1, 15, [ctx.wallets[2]]);
//         console.log(`Initializing quorum q2 "${q2}" - with user "${ctx.wallets[3]}"`);
//         await ctx.multi.initialize(q2, 1002, 1, 15, [ctx.wallets[3]]);

//         console.log('Both quorums are created');

//         console.log('Add user to q1 from q1');
//         let salt = randomSalt();
//         let expiry = expiryInFuture().toString();

//         console.log('Non owner adds to the quorum. Signer is part of the quorum but still not allowed')

//         salt = randomSalt();
//         let multiSig = await multiSigMethodCall(
// 			ctx, 'AddToQuorum',
// 			[
// 				{ type: 'address', name: '_address', value: ctx.wallets[4] },
// 				{ type: 'address', name: 'quorumId', value: q1 },
//                 { type: 'bytes32', name:'salt', value: salt},
// 				{ type: 'uint64', name: 'expiry', value: expiry },
// 			]
// 			, [ctx.sks[2]]);
//         await throws(ctx.multi.addToQuorum(ctx.wallets[4], q1, salt, expiry, multiSig.signature),
//             'MSC: invalid groupId for signer');

//         console.log('The owner adds to the quorum')
//         multiSig = await multiSigMethodCall(
// 			ctx, 'AddToQuorum',
// 			[
// 				{ type: 'address', name: '_address', value: ctx.wallets[4] },
// 				{ type: 'address', name: 'quorumId', value: q1 },
//                 { type: 'bytes32', name:'salt', value: salt},
// 				{ type: 'uint64', name: 'expiry', value: expiry },
// 			]
// 			, [ctx.sks[1]]);
//         await ctx.multi.addToQuorum(ctx.wallets[4], q1, salt, expiry, multiSig.signature);
//         console.log('User from q1 could add users to q1');

//     });
// });