import { ethers } from "ethers";
import { network } from "hardhat";

export async function hardhatAdvanceTimeAndBlock(totalTime: number, blocks: number) {
	if (blocks == 0) {
		throw new Error('Blocks must be at least one');
	}
	const theTime = Math.round(totalTime / blocks);
	const timeHex = '0x' + theTime.toString(16);
	const blockHex = '0x' + (blocks + 1).toString(16);
	const preTime = await hardhatGetTime();
	console.log('hardhat_mine', blockHex,  timeHex);
	await network.provider.send('hardhat_mine', [blockHex, timeHex]);
	const postTime = await hardhatGetTime();
	console.log(`hardhatAdvanceTimeAndBlock(${totalTime},${blocks}) => (${preTime} -> ${preTime})`);
	if (postTime <= preTime) {
		throw new Error(`Time did not expend`)
	}
}

export async function hardhatGetTime() {
	let block = await network.provider.request({method: 'eth_blockNumber'});
	let time = await network.provider.request({method: 'eth_getBlockByNumber', params: [block, false]}) as any;
	console.log('hardhatGetTime - blockNumber is ', block);
	return parseInt(time.timestamp, 16);
}

export async function advanceTimeAndBlock(time: number) {
	// const t = await getTime();
	await advanceTime(time);
	// await increaseTs(t + time);
	await advanceBlock();

    // return await ethers.getDefaultProvider().getBlock('latest');
}

export async function increaseTs(time: number) {
	console.log('evm_setNextBlockTimestamp', time);
	return network.provider.send('evm_setNextBlockTimestamp', [time]);
}

export async function advanceTime(time: number) {
	const res = await new Promise((resolve, reject) => network.provider.sendAsync({
						jsonrpc: '2.0',
						id: Date.now(),
            method: "evm_increaseTime",
            params: [time],
        }, (err, result) => {
            if (err) { return reject(err); }
            return resolve(result);
        }));
	console.log('res', res);
}

export async function advanceBlock() {
	return network.provider.send('evm_mine', []);
}

export async function getTime() {
	const currentNumber = await ethers.getDefaultProvider().getBlockNumber();
	const blk = await ethers.getDefaultProvider().getBlock(currentNumber);
	return blk.timestamp;
}
