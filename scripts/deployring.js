const hre = require("hardhat");

async function main() {
  // We get the contract to deploy
  const contract = await hre.ethers.getContractFactory("contracts/Ring.sol:Ring");

  // We set the constructor of the contract within a message
  const tokenContract = await contract.deploy();

  await tokenContract.deployed();
  console.log("Ring deployed to:", tokenContract.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

