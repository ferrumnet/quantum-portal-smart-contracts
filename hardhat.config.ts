import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition-ethers";
import { TEST_MNEMONICS } from "./test/common/TestAccounts";
import { ethers } from "ethers";
require("dotenv").config({ path: __dirname + "/localConfig/test.env" });

const getEnv = (env: string) => {
  const value = process.env[env];
  if (typeof value === "undefined") {
    console.warn(`${env} has not been set.`);
    // throw new Error(`${env} has not been set.`);
  }
  return value;
};

const accounts: any = process.env.TEST_ACCOUNT_PRIVATE_KEY ? [process.env.TEST_ACCOUNT_PRIVATE_KEY] : { mnemonic: TEST_MNEMONICS };

if (accounts.mnemonic) {
    let mnemonicWallet = ethers.HDNodeWallet.fromPhrase(TEST_MNEMONICS);
    console.log('Test account used from MNEMONIC', mnemonicWallet.privateKey, mnemonicWallet.address);
} else {
    let wallet = new ethers.Wallet(accounts[0]);
    console.log('Test account used from TEST_ACCOUNT_PRIVATE_KEY', wallet.address);
}

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      accounts,
      blockGasLimit: 3000000000,
      allowUnlimitedContractSize: true,
      // gas: 100000,
      // gasPrice: 20000000000,
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
      accounts,
      allowUnlimitedContractSize: true,
      //gas: 10000000, // this override is required for Substrate based evm chains
    },
    mainnet: {
      chainId: 1,
      url: `https://eth-mainnet.alchemyapi.io/v2/${getEnv("ALCHEMY_API_KEY") || "123123123"}`,
      accounts,
      gasPrice: 18000000000,
    },
    // bsctestnet: {
    //   chainId: 97,
    //   url: getEnv("BSC_TESTNET_LIVE_NETWORK"),
    //   accounts,
    //   gas: 1000000,
    //   // gasPrice: 20000000000,
    // },
    // bsc: {
    //   chainId: 56,
    //   url: getEnv("BSC_LIVE_NETWORK"),
    //   accounts,
    // },
    moonbeam: {
      chainId: 1287,
      url: "https://rpc.api.moonbase.moonbeam.network",
      accounts,
      allowUnlimitedContractSize: true,
      gas: 10000000, // this override is required for Substrate based evm chains
    },
    matic: {
      chainId: 137,
      url: "https://rpc-mainnet.maticvigil.com/",
      accounts,
      gasPrice: 16000000000,
    },
    mumbai: {
      chainId: 80001,
      url: "https://rpc-mumbai.maticvigil.com/",
      accounts,
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
      accounts,
      allowUnlimitedContractSize: true,
      gas: 10000000, // this override is required for Substrate based evm chains
    },
  },
  etherscan: {
    // Your API key for Etherscan
    apiKey: {
      bscTestnet: getEnv("BSCSCAN_API_KEY"),
      polygonMumbai: getEnv("POLYGONSCAN_API_KEY"),
      btfd_ghostnet: getEnv("POLYGONSCAN_API_KEY"),
  },
  customChains: [
    {
      network: "btfd_ghostnet",
      chainId: 42,
      urls: {
        apiURL: "https://ghostnet.dev.svcs.ferrumnetwork.io/api/",
        browserURL: "https://ghostnet.dev.svcs.ferrumnetwork.io/"
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
  }
};
export default config;
