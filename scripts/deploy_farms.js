const { utils, constants } = require("ethers");
const { ethers } = require("hardhat");
const { POOLS_INFO, DEFAULT_REWARD_INFO, PROJECT_ADMIN } = require("../config/config.js");
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

const tokenUri = "";

async function main() {
  const [deployer] = await ethers.getSigners();

  const chiefContract = await ethers.getContractFactory("NFTVillageChief");
  const chief = await chiefContract.deploy();
  await chief.deployed();
  console.log(`NFTVillageChief: ${chief.address}`);

  const feeReceiverContract = await ethers.getContractFactory("NFTVillageChiefFeeReceiver");
  const feeReceiver = await feeReceiverContract.deploy();
  await feeReceiver.deployed();
  console.log(`NFTVillageChiefFeeReceiver: ${feeReceiver.address}`);

  const projectHandlerContract = await ethers.getContractFactory("ProjectHandler");
  const projectHandlerArgs = [
    chief.address,
    deployer.address,
    0,
    0,
    0,
    feeReceiver.address,
    feeReceiver.address,
    feeReceiver.address,
  ];
  const projectHandler = await projectHandlerContract.deploy(...projectHandlerArgs);
  await projectHandler.deployed();
  console.log(`ProjectHandler: ${projectHandler.address}`);

  const cardHandlerContract = await ethers.getContractFactory("CardHandler");
  const cardHandlerArgs = [chief.address];
  const cardhandler = await cardHandlerContract.deploy(...cardHandlerArgs);
  await cardhandler.deployed();
  console.log(`CardHandler: ${cardhandler.address}`);

  await chief.connect(deployer).setProjectAndCardHandler(projectHandler.address, cardhandler.address);
  console.log(`NFTVillageChief: Project And Card Handler updated!`);

  const poolcardsContract = await ethers.getContractFactory("NFTVillageERC1155");
  const poolCardsArgs = ["NFTVillageCards", "NFTV", tokenUri];
  const poolCards = await poolcardsContract.deploy(...poolCardsArgs);
  await poolCards.deployed();
  console.log(`NFTVillageERC1155: ${poolCards.address}`);

  const testTokenContract = await ethers.getContractFactory("TestToken");
  const rewardTokenArgs = ["NFTVillageERC20"];
  const rewardToken = await testTokenContract.deploy(...rewardTokenArgs);
  await rewardToken.deployed();
  console.log(`RewardToken: ${rewardToken.address}`);

  const { provider } = ethers;

  // ----------------------- ADD PROJECT ---------------------------- //
  const block = await provider.getBlockNumber();
  await (
    await projectHandler.connect(deployer).addProject(
      // admin
      deployer.address,
      // feeRecipient
      PROJECT_ADMIN,
      // adminReward,
      0,
      // referralFee
      0,
      // startBlock
      block,
      // poolCards
      constants.AddressZero
    )
  ).wait();

  // --------------------------------- ADD POOLS -------------------------------- //
  for (let i = 0; i < POOLS_INFO.length; i++) {
    await (
      await projectHandler.connect(deployer).addPool(
        // projectId
        0,
        // pool
        {
          ...POOLS_INFO[i],
          stakedToken: rewardToken.address,
          maxDeposit: utils.parseEther("1000"),
          harvestInterval: 60 * 5,
          depositFee: 500,
        },
        // rewardInfo
        [{ ...DEFAULT_REWARD_INFO, token: rewardToken.address, rewardPerBlock: utils.parseEther("1") }],
        // requiredCards
        []
      )
    ).wait();
    console.log("Pools Added ", i + 1);
  }

  await (await projectHandler.connect(deployer).initializeProject(0)).wait();
  console.log("Project Initialized");

  await (await rewardToken.approve(chief.address, constants.MaxUint256)).wait();
  console.log("Approved");

  await (await chief.depositRewardToken(0, 0, 0, utils.parseEther("100000000"))).wait();
  console.log("Tokens deposited");

  await (await rewardToken.transfer(PROJECT_ADMIN, utils.parseEther("10000"))).wait();
  console.log("transfered");

  // --------------------------------- VERIFY CONTRACTS -------------------------------- //

  await sleep(100);

  await hre.run("verify:verify", {
    address: chief.address,
    constructorArguments: [],
  });
  await hre.run("verify:verify", {
    address: feeReceiver.address,
    constructorArguments: [],
  });
  await hre.run("verify:verify", {
    address: projectHandler.address,
    constructorArguments: projectHandlerArgs,
  });
  await hre.run("verify:verify", {
    address: cardhandler.address,
    constructorArguments: cardHandlerArgs,
  });
  await hre.run("verify:verify", {
    address: poolCards.address,
    constructorArguments: poolCardsArgs,
  });
  await hre.run("verify:verify", {
    address: rewardToken.address,
    constructorArguments: rewardTokenArgs,
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
