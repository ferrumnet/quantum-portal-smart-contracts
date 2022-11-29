import { ethers } from "hardhat";
​
async function main() {
  const [deployer] = await ethers.getSigners();
​
  console.log("Deploying contracts with the account:", deployer.address);
​
  console.log("Account balance:", (await deployer.getBalance()).toString());
​
  const FerrumDep = await ethers.getContractFactory("FerrumDeployer");
  const ferrumDep = await FerrumDep.deploy();
​
  console.log("FerrumDep address:", ferrumDep.address);
}
​
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });