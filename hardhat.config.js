require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.18",
  networks: {
    praseody: {
      url: 'https://pr-rpc.canxium.net',
      accounts: [""],
      hardfork: "london"
    }
  },
  etherscan: {
    apiKey: {
      praseody: "abc"
    },
    customChains: [
      {
        network: "praseody",
        chainId: 30203,
        urls: {
          apiURL: "https://praseody-scan.canxium.net/api",
          browserURL: "https://praseody-scan.canxium.net"
        }
      }
    ]
  }
};
