import { ethers } from "ethers";
import { network } from "hardhat";

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
