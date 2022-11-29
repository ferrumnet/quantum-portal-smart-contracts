
# Multi-chain staking example - Step by step

Multi-chain staking has one master, and one or more clients.

Following actions are done on the master:

1. init
2. setRewardToken
3. stake
4. closeStakePeriod
5. enableRewardDistribution
6. addRewards
7. closePosition


Following actions are done on the client:

- stake

## Admin workflow

Admin will do the following:
- Deploy the master and client (using `deployMultiChainStaking` script)
- Init staking on master
- Set the reward token
- Wait for people to stake
- Close the Stake period
- Add rewards
- Enable reward distribution when the staking period is finished

## User workflow

A user will do the following:
- Stake (on the master or client chain)
- Close position (on the master chain), but will receive their tokens on the staked chain

### Deploy the master 

Before running any deploy command you need to set the private key

```
$ export TEST_ACCOUNT_PRIVATE_KEY=0x...
```

Then:

```
$ mode=MASTER owner=0xD164F5DD60d11100771BAB79B0868Ae835DD23f0 npx hardhat run --network <network_name> ./scripts/quantumPortal/poc/examples/deployMultiChainStaking.ts
```

## Deploying the client

Open `deployMultiChainStaking.ts` and change the following line:

```
await helper.init([
        {name: 'MultiChainStakingMaster', address: '<Enter the master address here...>',},
        {name: 'MultiChainStakingClient', address: '',},
    ]);
```

Then:

```
$ mode=CLIENT owner=0xD164F5DD60d11100771BAB79B0868Ae835DD23f0 npx hardhat run --network <network_name> ./scripts/quantumPortal/poc/examples/deployMultiChainStaking.ts
```

Then enter the client address in init function above
