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
  }
};

export default config;