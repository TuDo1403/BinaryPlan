import { Contract, ContractFactory } from "ethers";
import { ethers, upgrades } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config()

async function main() {
  // const BinaryPlan = await ethers.getContractFactory("BinaryPlan");
  // const binaryPlan = await BinaryPlan.deploy(
  //   process.env.AUTHORITY || ""
  // );

  // await binaryPlan.deployed();

  // console.log(`BinaryPlan deployed to ${binaryPlan.address}`);

  // const Factory = await ethers.getContractFactory("ReferralTreeFactory");
  // const factory = await Factory.deploy(
  //   process.env.AUTHORITY || "",
  //   "0x2a84d64763269aDeF396799864E23Ae5Cdb3F3BD"
  //   // binaryPlan.address
  // );

  // await factory.deployed();

  // console.log(`Factory deployed to ${factory.address}`);

  const NFTStaking: ContractFactory = await ethers.getContractFactory("ERC721Staking");
    const nftStaking: Contract = await upgrades.deployProxy(
        NFTStaking,
        ["0xAAc6CE62CD4253c1b5A2902b5A1b1D9464256A54", "0xcf7C84E60c468007aB30FF75Bd2467d6e357d840"],
        { kind: "uups", initializer: "initialize"},
    );
    await nftStaking.deployed();
    console.log("NFTStaking deployed to : ", nftStaking.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
