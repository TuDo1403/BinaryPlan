import { Contract, ContractFactory } from "ethers";
import { ethers, upgrades } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config()

async function main() {
  const BinaryPlan = await ethers.getContractFactory("BinaryPlan");
  const binaryPlan = await BinaryPlan.deploy(
    process.env.AUTHORITY || ""
  );

  await binaryPlan.deployed();

  console.log(`BinaryPlan deployed to ${binaryPlan.address}`);

  // const Factory = await ethers.getContractFactory("ReferralTreeFactory");
  // const factory = await Factory.deploy(
  //   process.env.AUTHORITY || "",
  //   "0x2a84d64763269aDeF396799864E23Ae5Cdb3F3BD"
  //   // binaryPlan.address
  // );

  // await factory.deployed();

  // console.log(`Factory deployed to ${factory.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
