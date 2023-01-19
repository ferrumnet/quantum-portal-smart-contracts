

# Deploy quantum portal

Note : remember to change the DEPLOY_SALT value in consts file

1. Deploy on master chain

npx hardhat run --network bsctestnet ./scripts/quantumPortal/poc/deployQuantumPortal.ts

2. Deploy on client chain

npx hardhat run --network mumbai ./scripts/quantumPortal/poc/deployQuantumPortal.ts


# Deploy Multichain staking example

1. Set all values
 - Ensure the master and client addresses are removed from the deployMultiChainStaking.ts script
 - Update the deployTestHelper file with the new poc contract address

1. Deploy on master

    mode=MASTER owner=0xD164F5DD60d11100771BAB79B0868Ae835DD23f0 npx hardhat run --network bsctestnet ./scripts/quantumPortal/poc/examples/deployMultiChainStaking.ts

2. Deploying the client

Open `deployMultiChainStaking.ts` and change the following line:

```
await helper.init([
        {name: 'MultiChainStakingMaster', address: '<Enter the master address here...>',},
        {name: 'MultiChainStakingClient', address: '',},
    ]);
```

Then:

```
  mode=CLIENT owner=0xD164F5DD60d11100771BAB79B0868Ae835DD23f0 npx hardhat run --network mumbai ./scripts/quantumPortal/poc/examples/deployMultiChainStaking.ts
```

3. Init the master contract

    Set the client contract addess in deployMultiChainStaking.ts

    mode=INIT_MASTER owner=0xD164F5DD60d11100771BAB79B0868Ae835DD23f0 npx hardhat run --network bsctestnet ./scripts/quantumPortal/poc/examples/deployMultiChainStaking.ts

4. Verify the master, client and authority manager contract (Remember to set the apikey for etherscan in configs)

    Verify the master contract

    ```
    npx hardhat verify --network bsctestnet <MASTER_CONTRACT_ADDRESS>
    ```

    Verify the client contract

    ```
    npx hardhat verify --network mumbai <CLIENT_CONTRACT_ADDRESS>
    ```

    Verify the authority manager contract on both chains

    ```
    npx hardhat verify --network mumbai <AUTHORITY_MANAGER_ADDRESS>
    npx hardhat verify --network bsctestnet <AUTHORITY_MANAGER_ADDRESS>
    ```


5. Add the finalizer to the authority manager list

6. Approve the token contract for the client staking contract and call stake() function 
