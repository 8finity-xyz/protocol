import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";

const accounts = Object.entries(process.env)
  .filter(([k, _]) => k.includes("_ACCOUNT"))
  .map(([_, v]) => v)
  .filter(v => v !== undefined)

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 99999,
          },
        },
      },
    ]
  },
  networks: {
    sonic: {
      url: "https://rpc.soniclabs.com",
      chainId: 146,
      accounts
    },
    sonicBlazeTestnet: {
      url: "https://rpc.blaze.soniclabs.com",
      chainId: 57054,
      accounts
    }
  },
  etherscan: {
    apiKey: {
      sonic: process.env.SONICSCAN_API_KEY!,
      sonicBlazeTestnet: process.env.SONICSCAN_API_KEY!,
    },
    customChains: [
      {
        network: "sonic",
        chainId: 146,
        urls: {
          apiURL: "https://api.sonicscan.org/api",
          browserURL: "https://sonicscan.org"
        }
      },
      {
        network: "sonicBlazeTestnet",
        chainId: 57054,
        urls: {
          apiURL: "https://api-testnet.sonicscan.org/api",
          browserURL: "https://testnet.sonicscan.org"
        }
      }
    ]
  },

};

export default config;