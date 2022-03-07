const { ethers, waffle } = require("hardhat");
const { expect, use, util } = require("chai");
const { solidity } = require("ethereum-waffle");
const { utils } = ethers;

use(solidity);

const sleep = async (s) => {
    for (let i = s; i > 0; i--) {
      process.stdout.write(`\r \\ ${i} waiting..`);
      await new Promise((resolve) => setTimeout(resolve, 250));
      process.stdout.write(`\r | ${i} waiting..`);
      await new Promise((resolve) => setTimeout(resolve, 250));
      process.stdout.write(`\r / ${i} waiting..`);
      await new Promise((resolve) => setTimeout(resolve, 250));
      process.stdout.write(`\r - ${i} waiting..`);
      await new Promise((resolve) => setTimeout(resolve, 250));
      if (i === 1) process.stdout.clearLine();
    }
  };

const TOKEN_AMOUNT = utils.parseEther("100000000");

let token, privateSale, deployer, user1, signer;

async function main() {
  [deployer, signer, user1] = await ethers.getSigners();

  const erc20Contract = await ethers.getContractFactory("TestToken");
  token = await erc20Contract.deploy("TEST");

  console.log("token", token.address);
  console.log(".................................................");

  console.log("..................................................");
  console.log("Minting.....");

  const privateSaleContract = await ethers.getContractFactory("NFTVillagePrivateSaleClaim");
  privateSale = await privateSaleContract.deploy(token.address);

  console.log("PrivateSale", privateSale.address);
  console.log(".................................................");

  await (await token.connect(deployer).mint(privateSale.address, TOKEN_AMOUNT)).wait();

  await privateSale.connect(deployer).grandRewardSignerRole(signer.address);
  await privateSale.connect(deployer).setClaimEnabled(true);

  const CLAIM_SIGNER_ROLE = await privateSale.CLAIM_SIGNER_ROLE();

  await privateSale.hasRole(CLAIM_SIGNER_ROLE, signer.address);

  
  await sleep(80);


}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
