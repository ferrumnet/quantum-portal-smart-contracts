
echo "Starting ferrum miner and finalizer for tests"
# # remove any existing data from chain
rm -rf ./chain

# # generate chain spec
./target/release/ferrum-network build-spec --disable-default-bootnode > ferrum-local-testnet.json

# # insert the signing keys for alice
./target/release/ferrum-network key insert --key-type ofsg --scheme ecdsa --base-path ./chain/alice --chain ferrum-local-testnet.json --suri //Alice

# insert the signing keys for bob
./target/release/ferrum-network key insert --key-type ofsg --scheme ecdsa --base-path ./chain/bob --chain ferrum-local-testnet.json --suri //Bob

# start relaychain and parachain in background
polkadot-launch ./scripts/polkadot-launch/config.json

echo "Starting evm network for tests"
npx hardhat node

echo "Deploying QP to ferrum network"
QP_CONFIG_FILE=./localConfig/QpDeployConfig.yml npx hardhat run --network ferrum_testnet ../../quantum-portal-smart-contracts/scripts/quantumPortal/poc/deployQuantumPortal.ts

echo "Deploying QP to evm network"
QP_CONFIG_FILE=./localConfig/QpDeployConfig.yml npx hardhat run --network evm_testnet ../../quantum-portal-smart-contracts/scripts/quantumPortal/poc/deployQuantumPortal.ts

echo "Deploy MCS to ferrum network"
mode=MASTER owner=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 npx hardhat run --network ferrum_testnet ./scripts/quantumPortal/poc/examples/deployMultiChainStaking.ts

echo "Deploying MCS to evm network"
mode=CLIENT owner=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 npx hardhat run --network evm_testnet ./scripts/quantumPortal/poc/examples/deployMultiChainStaking.ts

echo "starting integration tests"
yarn test