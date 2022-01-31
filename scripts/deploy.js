const fs = require('fs');

// Mumbai
const keyHash = '0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4';
const VRFCoordinator = '0x8C7382F9D8f56b33781fE506E897a4F1e2d17255';
const linkToken = '0x326C977E6efc84E512bB9C30f76E30c160eD06FB';
// Polygon Mainnet
// const keyHash = '0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da';
// const VRFCoordinator = '0x3d2341ADb2D31f1c5530cDC622016af293177AE0';
// const linkToken = '0xb0897686c545045aFc77CF20eC7A532E3120E0F1';


async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contract with the account: ${deployer.address}`);

  const balance = await deployer.getBalance();
  console.log(`Account balance: ${balance.toString()}`);

  const WunderNFT = await ethers.getContractFactory('WunderNFT');
  const contract = await WunderNFT.deploy();
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