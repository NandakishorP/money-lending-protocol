require("@nomiclabs/hardhat-waffle")
require("@nomiclabs/hardhat-etherscan")
require("hardhat-deploy")
require("solidity-coverage")
require("hardhat-gas-reporter")
require("hardhat-contract-sizer")
require("dotenv").config()

const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL
const PRIVATE_KEY = process.env.PRIVATE_KEY
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY
const REPORT_GAS = process.env.REPORT_GAS.toLowerCase() === "true" || false

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 31337,
    },
    localhost: {
      chainId: 31337,
    },
    sepolia: {
      url: SEPOLIA_RPC_URL,
      accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
      saveDeployments: true,
      chainId: 11155111,
      blockConfirmation: 6,
    },
  },
  // etherscan: {
  //   apiKey: {
  //     sepolia: ETHERSCAN_API_KEY,
  //   },
  // },
  gasReporter: {
    enabled: REPORT_GAS,
    currency: "USD",
    outputFile: "gas-report.txt",
    noColors: true,
  },
  // contractSizer: {
  //   runOnCompile: false,
  //   only: ["OurToken"],
  // },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    user1: {
      default: 1,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.7",
      },
      // {
      //   version: "0.4.24",
      // },

    ],
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
    deployments: "./deployments",
  },
  external: {
    contracts: [
      {
        artifacts: "@chainlink/contracts/src/v0.8/tests",
      },
    ],
  },
  // mocha: {
  //   timeout: 200000,
  // },
}
