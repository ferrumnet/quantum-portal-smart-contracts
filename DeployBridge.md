## Deploy bridge

```
# Deploy bridge
$ CONTRACT_OWNER=0xa6F55AA418C9F312f58E36776e8173eE0B1cF32B npx hardhat run ./scripts/deployBridge.ts --network bsctestnet

# address: 0x89262B7bd8244b01fbce9e1610bF1D9F5D97C877
$ npx hardhat verify 0x89262B7bd8244b01fbce9e1610bF1D9F5D97C877 --network bsctestnet

$ CONTRACT_OWNER=0xa6F55AA418C9F312f58E36776e8173eE0B1cF32B npx hardhat run ./scripts/deployTaxDistributor.ts --network bsctestnet

# 0x3C31720D705C59B3BA7F1aaD743B727Db77a3Cfc
$ npx hardhat verify 0x3C31720D705C59B3BA7F1aaD743B727Db77a3Cfc --network bsctestnet
```

#### Bridge configs
* [Owner] Set the admin to $ADMIN=0x467502Ef1c444f98349dacdf0223CCb5e2019f36
* [Owner] Set the signer 0xcde782dee9643b02dde8a11499ede81ec1d05dd3
* [Owner] Set the fee dist 0x3C31720D705C59B3BA7F1aaD743B727Db77a3Cfc
* [Admin] Set fee for FRM (0xfe00ee6f00dd7ed533157f6250656b4e007e7179)
* [Admin] Set allowed targets for FRM: (one for each chain ID) (4, 97, 80001)


#### Tax distributor config
* [Owner] Set the admin to $ADMIN=0x467502Ef1c444f98349dacdf0223CCb5e2019f36
* [Admin] Add (bridge) as allowed actor: 0x89262B7bd8244b01fbce9e1610bF1D9F5D97C877
* [Admin] Set global target infos (e.g. infos: [["0x1234540b22a86cE9338584AF174eAb2D3AE817FD",2],["0x0000000000000000000000000000000000000000",1]], weights: 0x3c28)


