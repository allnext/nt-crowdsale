// hardhat.config.js
require("@nomiclabs/hardhat-waffle");
// require("@nomiclabs/hardhat-solpp");
const {
  mnemonic, mnemonicTest
} = require("./secrets.json");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.3",
  settings: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  },
  defaultNetwork: "bscmainnet",
  networks: {
    bscmainnet: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      gasPrice: 30000000000,
      gas: 1500000,
      accounts: {
        mnemonic
      }
    },
    bsctestnet: {
      url: "https://data-seed-prebsc-1-s2.binance.org:8545/",
      chainId: 97,
      gasPrice: 20000000000,
      accounts: {
        mnemonic: mnemonicTest
      }
    }
  }
};