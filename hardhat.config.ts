import "@nomiclabs/hardhat-waffle";
import "@openzeppelin/hardhat-upgrades";
import {task} from "hardhat/config";
import "hardhat-gas-reporter"
import "@symblox/hardhat-dotenv";

task("accounts", "Prints the list of accounts", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

const config = {
  solidity: {
    compilers: [
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          },
          evmVersion: "istanbul"
        }
      },
      {
        version: "0.7.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          },
          evmVersion: "istanbul"
        }
      }
    ]
  },
  paths: {
    tests: "./tests",
    sources: "./contracts"
  },
  mocha: {timeout: 120000},
  gasReporter: {
    currency: 'USD',
    gasPrice: 10
  }
};

export default config;
