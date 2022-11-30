// import { expect } from "chai";
// import { ethers } from "hardhat";
// import { deployDummyToken, getCtx } from "./Utils";

// describe("Deploy with config", function () {
// 	it("Deploy non ownable", async function () {
// 		const ctx = await getCtx();
// 		const actual = await deployDummyToken(ctx);
// 		expect(await actual.balanceOf(ctx.owner)).to.equal(await actual.totalSupply());
// 	});
// 	it("Deploy ownable", async function () {
// 		const ctx = await getCtx();
// 		const actual = await deployDummyToken(ctx, 'DummyTokenOwnable', ctx.owner);
// 		expect(await actual.balanceOf(ctx.owner)).to.equal(await actual.totalSupply());
// 		expect(await actual.owner()).to.equal(ctx.owner);
// 	});
// });
