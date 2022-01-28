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