const fs = require('fs');

const names = ["Berlin", "Düsseldorf", "London", "Oxford", "NewYork", "LosAngeles", "Shanghai", "Peking", "Deutschland", "England", "USA", "China", "Europa", "Nordamerika", "Asien", "Welt"]
const parents = ["Deutschland", "Deutschland", "England", "England", "USA", "USA", "China", "China", "Europa", "Europa", "Nordamerika", "Asien", "Welt", "Welt", "Welt", "Welt"]

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contract with the account: ${deployer.address}`);

  const balance = await deployer.getBalance();
  console.log(`Account balance: ${balance.toString()}`);

  const WunderNFT = await ethers.getContractFactory('WunderNFT');
  const contract = await WunderNFT.deploy(names, parents);
  console.log(`Token address: ${contract.address}`);

  const contractData = {
    address: contract.address,
    abi: contract.interface.format('full')
  }

  fs.writeFileSync('deployed/WunderNFT.json', JSON.stringify(contractData));
}

main()
  .then(() => {
    process.exit(0)
  })
  .catch((err) => {
    console.error(err)
    process.exit(1)
  })