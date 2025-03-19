# Deploying the Quantum Portal

## Deploying the Quantum Portal

```bash
npx hardhat run scripts/deployQp.ts --network arbitrumOne
```

## Verifying the Quantum Portal

```bash
npx hardhat ignition verify chain-<chainId>
```

## Deploying to Ferrum Network

Gas estimation fails when we are deploying to Ferrum Network. Hardhat inition does not have a way to hardcode
the gas limit, so we edit thei following file `node_modules/@nomicfoundation/ignition-core/dist/src/internal/execution/jsonrpc-client.js` and  change the code as follows:

```js
  async estimateGas(estimateGasParams) {
   console.log('Estimating gas');
   return BigInt(7000000)
   ...
```

Then call:

```bash
npx hardhat run scripts/deployQp.ts --network ferrum_mainnet
```

## Post deployment

We need to make sure all the following are properly conigured:

**POC**: `feeTarget` is `MinerMgr`, and `feeToken` is `FRM`
**LedgerMgr**: `MinerMinimumStake` is set.
**AuthorityMgr**: `baseToken` is set. needs to be `initialized` with authorities. See[auth.init] section.
**FeeConvertor**: `feePerByte` is set. For an arbi-frm pair system it is ~ 0.03FRM per byte. Calculate the most expensive network.
 `qpFeeToken` is set (optional, not used by contracts).
  Set `admin` to the bot. Then run the token price bot `setChainGasPrices`.
**NativeFeeRepo**: `portal` is set. `feeConvertor` is set. Fund it with FRM.

**NOTE**: price is target chain price/FRM. For example ETH/FRM will be how many FRM per ETH.


## Further actions post deploymenmt
After deploying and configuring the contracts, we still need the following before QP can start mining and finalizing transactions:

We will have four roles on each chain:
1- Mining operator: the account that mines from the node
2- Miner (or delegatee): The account that is registered as miner, assigns operator, and stakers stake for them
3- Mining staker(s): Account(s) that stake for the miner
4- Authority operator: The account that is registered as authority operator, and can sign off on transactions
5- Authority (or delegatee): The account that is registered as authority, and can assign operator to the authority

### UI for above configuration

There is a UI in the `ferrum-gateway/qp-explorer-frontend/src/pages/examples/qpMinerStake/QpMinerStake.tsx`
 NOTE: Above UI works with node V14. And make sure to update the gateway contract in configs
Open it using `http://localhost:3000/qpminerstake`

