require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.4",
  networks: {
    fantomtest: {
      url: "https://rpc.testnet.fantom.network",
      accounts: ["1e4ef429ba950c2d110eb073929927a7c90a4260baed308480352e02a9ef04ca"],
      chainId: 4002,
      // live: false,
      // saveDeployments: true,
      // gasMultiplier: 2,
    },
  },
  etherscan:{
    apiKey: "RXW8JEDX1ZAA1796387AIQQI484D8CKWT7"
  }
};