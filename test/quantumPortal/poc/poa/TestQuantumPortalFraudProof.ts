import { getCtx } from "foundry-contracts/dist/test/common/Utils";

describe("Test fraud proofs", function () {
	it('finalizer can mark some blocks as invalid, and they will get refunded - simple', async function() {
        // create one tx and one block
        // mine the block
        // finalize the block as invalid.
        // make sure we are refunded
        const ctx = await getCtx();
    });

	it('finalizer can mark some blocks as invalid, and they will get refunded - advanced middle failed', async function() {
        // create five txs and three blocks
        // middle one invalid
        // finalize invalid block
        // make sure we are refunded, and the others have gone through
    });

	it('finalizer can mark some blocks as invalid, and they will get refunded - advanced last failed', async function() {
        // create five txs and three blocks
        // last one invalid
        // finalize invalid block
        // make sure we are refunded, and the others have gone through
    });
});