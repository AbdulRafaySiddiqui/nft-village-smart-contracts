const { utils, constants } = require("ethers");
const { ethers } = require("hardhat");
const hre = require("hardhat");

const ROUTERS = {
  PANCAKE: "0x10ED43C718714eb63d5aA57B78B54704E256024E",
  PANCAKE_TESTNET: "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3",
  UNISWAP: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
  SUSHISWAP_TESTNET: "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
  PANGALIN: "0xE54Ca86531e17Ef3616d22Ca28b0D458b6C89106",
};

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
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

const PROJECT_FEE = utils.parseEther("0");
const POOL_FEE = utils.parseEther("0");
const REWARD_FEE = "0"; // 5%
const REWARD_PER_BLOCK = utils.parseEther("1");
const MIN_DEPOSIT = utils.parseEther("0");

let pool;
const rewardInfo = [];
const harvestCards = [];
const multiplierCards = [];
const feeCards = [];
const requiredCards = [];
let user2 = "0x283070d8D9ff69fCC9f84afE7013C1C32Fd5A19F";
const tokenUri = "";

async function main() {
  //Deploy contracts
  const [deployer] = await ethers.getSigners();

  const poolcardsContract = await ethers.getContractFactory("NFTVillageERC1155");
  const poolCards = await poolcardsContract.attach("0xB5F5CBDC9C6F553B9A276E9bEaE0C4c1fB0B8896");
  //   const poolCards = await poolcardsContract.deploy("NFTVillageCards", "NFTV", tokenUri);
  console.log(`NFTVillageERC1155: ${poolCards.address}`);

  const tokenIds = [1, 2, 3, 4, 5, 6, 7, 8, 9];

  for (let i = 0; i < tokenIds.length; i++) {
    await (await poolCards.addMultiplierCard(tokenIds[i], 100 * i)).wait();
    console.log("minting", tokenIds[i]);
  }
  await (
    await poolCards.mintBatch(
      deployer.address,
      tokenIds,
      tokenIds.map((e) => 5),
      []
    )
  ).wait();
  await (
    await poolCards.mintBatch(
      user2,
      tokenIds,
      tokenIds.map((e) => 5),
      []
    )
  ).wait();
  console.log("Cards Minted");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
