const hre = require("hardhat");

async function main() {
  // We get the contract to deploy
  const contract = await hre.ethers.getContractFactory("contracts/RingFarmFlattened.sol:RingFarm");

  // We set the constructor of the contract within a message
  const farmContract = await contract.deploy();

  await farmContract.deployed();
  console.log("RingFarm deployed to:", farmContract.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

