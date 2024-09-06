import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition-ethers";
import "hardhat-contract-sizer"
import "@nomicfoundation/hardhat-verify";
import { Secrets } from "foundry-contracts/dist/test/common/Secrets";
import deasync from 'deasync';
import { TEST_MNEMONICS } from "./test/common/TestAccounts";
import { ethers } from "ethers";
require("dotenv").config({path: __dirname + '/localConfig/.env'});

function logLocalAccount(accounts: any) {
  if (accounts?.mnemonic) {
      let mnemonicWallet = ethers.HDNodeWallet.fromPhrase(accounts.mnemonic);
      console.log('Test account used from MNEMONIC', mnemonicWallet.privateKey, mnemonicWallet.address);
  } else {
    let wallet = new ethers.Wallet(accounts[0]);
    console.log('Single test account used:', wallet.address);
  }
}

let accounts: any = undefined;
if (process.env.PAIVATE_KEY_SECRET_ARN) {
  console.log('Getting secret from AWS Secret Manager');
  let done = false;
  Secrets.fromAws().then((secret) => {
    // Use the default mnemonics
    accounts = { mnemonic: secret.DEV_MNEMONICS };
    // Or use a single account. Check available keys from the secret manager
    // accounts = [secret.PRIVATEKEY_TEST_VALIDATOR];
    done = true;
  }).catch((e) => {;
    console.error('Failed to get secret from PAIVATE_KEY_SECRET_ARN environment', e);
    done = true;
  });

  while (!done) { deasync.sleep(100); } // Sync the secrets call
} else {
  accounts = process.env.TEST_ACCOUNT_PRIVATE_KEY ? [process.env.TEST_ACCOUNT_PRIVATE_KEY] : { mnemonic: TEST_MNEMONICS };
}
logLocalAccount(accounts);

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 130,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      blockGasLimit: 3000000000,
      allowUnlimitedContractSize: true,
      accounts: accounts.constructor.name == "Array" ? { privateKey: accounts[0], balance: ethers.parseEther("1000").toString() } : accounts,
    },
    local: {
      // chainId: 97,
      url: 'http://127.0.0.1:8545',
      accounts,
      // gas: 1000000,
      // gasPrice: 20000000000,
    },
    btfd_ghostnet: {
      chainId: 42,
      url: "http://ghostnet.dev.svcs.ferrumnetwork.io:9944",
      allowUnlimitedContractSize: true,
      accounts,
      //gas: 10000000, // this override is required for Substrate based evm chains
    },
    mainnet: {
      chainId: 1,
      url: process.env.ETH_LIVE_NETWORK,
      // gasPrice: 18000000000,
      accounts,
    },
    bsctestnet: {
      chainId: 97,
      url: process.env.BSC_TESTNET_LIVE_NETWORK,
      accounts,
      // gas: 1000000,
      // gasPrice: 20000000000,
    },
    bsc: {
      chainId: 56,
      url: "https://bsc-dataseed2.defibit.io",
      accounts,
      // accounts: [process.env.QP_DEPLOYER_KEY!]
    },
    moonbeam: {
      chainId: 1287,
      url: "https://rpc.api.moonbase.moonbeam.network",
      allowUnlimitedContractSize: true,
      gas: 10000000, // this override is required for Substrate based evm chains
      accounts,
    },
    matic: {
      chainId: 137,
      url: "https://rpc-mainnet.maticvigil.com/",
      gasPrice: 16000000000,
      accounts,
    },
    mumbai: {
      chainId: 80001,
      url: "https://rpc-mumbai.maticvigil.com/",
      accounts,
      // accounts: [process.env.QP_DEPLOYER_KEY!]
      // gasPrice: 16000000000,
      // gas: 10000000,
    },
    avax: {
      chainId: 43114,
      url: "https://api.avax.network/ext/bc/C/rpc",
      accounts,
    },
    avaxtestnet: {
      chainId: 43113,
      url: "https://api.avax-test.network/ext/bc/C/rpc",
      accounts,
    },
    ferrum_testnet_poc: {
      chainId: 26000,
      url: "http://testnet.dev.svcs.ferrumnetwork.io:9933",
      accounts,
    },
    shibuya_testnet: {
      chainId: 4369,
      url: "http://127.0.0.1:9933/",
      allowUnlimitedContractSize: true,
      // gas: 10000000, // this override is required for Substrate based evm chains
      accounts,
    },
    arbitrumOne: {
      url: process.env.ARBITRUM_RPC!,
      accounts: [process.env.QP_DEPLOYER_KEY!]
    },
    base: {
      url: process.env.BASE_RPC!,
      accounts: [process.env.QP_DEPLOYER_KEY!]
    },
    ferrum_testnet: {
      chainId: 26100,
      url: "https://testnet.dev.svcs.ferrumnetwork.io",
      // accounts: [process.env.QP_DEPLOYER_KEY!],
      allowUnlimitedContractSize: true,
      gas: 10000000, // this override is required for Substrate based evm chains
      accounts,
    },
  },
  etherscan: {
    // Your API key for Etherscan
    apiKey: {
      // bscTestnet: getEnv("BSCSCAN_API_KEY"),
      // polygonMumbai: getEnv("POLYGONSCAN_API_KEY"),
      // btfd_ghostnet: getEnv("POLYGONSCAN_API_KEY"),
      arbitrumOne: process.env.ARBISCAN_API_KEY!,
      base: process.env.BASESCAN_API_KEY!,
      bsc: process.env.BSCSCAN_API_KEY!,
      ferrum_testnet: 'empty'
  },
  customChains: [
    {
      network: "btfd_ghostnet",
      chainId: 42,
      urls: {
        apiURL: "https://ghostnet.dev.svcs.ferrumnetwork.io/api/",
        browserURL: "https://ghostnet.dev.svcs.ferrumnetwork.io/"
      }
    },
    {
      network: "ferrum_testnet",
      chainId: 26100,
      urls: {
        apiURL: "https://testnet-explorer.svcs.ferrumnetwork.io/api",
        browserURL: "http://https://testnet-explorer.svcs.ferrumnetwork.io"
      }
    }
  ]
  },
  sourcify: {
    // Disabled by default
    // Doesn't need an API key
    enabled: true,
    apiUrl: "https://sourcify.dev/server",
    browserUrl: "https://repo.sourcify.dev",
  },
  ignition: {
    strategyConfig: {
      create2: {
        // To learn more about salts, see the CreateX documentation
        salt: "0x0000000000000000000000000000000000000000000000000000000000000007"
        // salt: "0x46657272756D4E6574776F726B2D746573746E65743A30312E3030312E303037",
      },
    },
  },
};

export default config;
