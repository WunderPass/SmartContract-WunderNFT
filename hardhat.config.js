/**
 * @type import('hardhat/config').HardhatUserConfig
 */
require('@nomiclabs/hardhat-waffle');
require("@appliedblockchain/chainlink-plugins-fund-link");
require('dotenv').config()
require('hardhat-contract-sizer');
const fs = require('fs');

task(
  "compile",
  "Compiles the contract and prints the size of the deployed bytecode",
  async function (taskArguments, hre, runSuper) {
    await runSuper();
    fs.readdirSync('./artifacts/contracts/').forEach(contractFolder => {
      fs.readdirSync(`./artifacts/contracts/${contractFolder}/`).forEach(jsonFile => {
        if (jsonFile.match(/.*[^\.][^d][^b][^g]\.json/)) {
          let contract = JSON.parse(fs.readFileSync('./artifacts/contracts/wunder_nft.sol/WunderNFT.json', 'utf8'));
          fs.writeFileSync('size.hex', contract.deployedBytecode);
          let stats = fs.statSync('size.hex')
          console.log(`Contract ${contractFolder} has a size of ${stats.size} bytes`);
          fs.unlinkSync('size.hex');
        }
      })
    });
  }
);

module.exports = {
  solidity: {
    version: "0.8.0",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  defaultNetwork: "hardhat",
  networks: {
    rinkeby: {
      url: process.env.INFURA_URL,
      accounts: [`0x${process.env.PRIVATE_KEY}`, '0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e', '0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356']
    },
    mumbai: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: [`0x${process.env.PRIVATE_KEY}`]
    }
  },
  mocha: {
    timeout: 1000000
  }
};