import "@nomiclabs/hardhat-waffle";
import "@openzeppelin/hardhat-upgrades";
import {task} from "hardhat/config";
import "hardhat-gas-reporter"
import "@symblox/hardhat-abi-gen";
import "@symblox/hardhat-dotenv";

task("accounts", "Prints the list of accounts", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

const privateKeys = process.env["PRIVATE_KEYS"].split(",");

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
  // defaultNetwork: "rinkeby",
  networks: {
    // rinkeby: {
    //   url: "https://eth-mainnet.alchemyapi.io/v2/123abc123abc123abc123abc123abcde",
    //   accounts: [privateKey1, privateKey2, ...]
    // }
    bsctest: {
      url: "https://data-seed-prebsc-2-s2.binance.org:8545/",
      accounts: privateKeys,
      timeout: 600000 // 10 mins
    }
  },
  mocha: {timeout: 120000},
  abiExporter: {
    path: "./data/abi",
    clear: false,
    flat: true,
    only: [
      "SafeDecimalMath",
      "SymbloxToken",
      "SynthManager",
      "Issuer",
      "SystemStatus",
      "AccessControl",
      "OracleBase",
      "OracleBandProtocol",
      "OracleChainLink",
      "Debt",
      "Collateral",
      "RewardEscrow",
      "Exchanger",
      "SymbloxVoucher",
      "Vault",
      "BaseToken",
      "ConnectorFactory",
      "Connector",
      "IERC20"
    ],
    except: ["interfaces", "mock", "upgradeable", "Test"]
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 10
  }
};

export default config;
