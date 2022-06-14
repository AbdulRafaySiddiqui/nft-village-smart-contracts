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

const verify = async (contractAddress, args = [], name, wait = 100) => {
  try {
    await hre.run("verify:verify", {
      address: contractAddress,
      constructorArguments: args,
    });
    return true;
  } catch (e) {
    if (
      String(e).indexOf(`${contractAddress} has no bytecode`) !== -1 ||
      String(e).indexOf(`${contractAddress} does not have bytecode`) !== -1
    ) {
      console.log(`Verification failed, waiting ${wait} seconds for etherscan to pick the deployed contract`);
      await sleep(wait);
    }

    try {
      await hre.run("verify:verify", {
        address: contractAddress,
        constructorArguments: args,
      });
      return true;
    } catch (e) {
      if (String(e).indexOf("Already Verified") !== -1 || String(e).indexOf("Already verified") !== -1) {
        console.log(name ?? contractAddress, "is already verified!");
        return true;
      } else {
        console.log(e);
        return false;
      }
    }
  }
};

const deploy = async (name, args = [], shouldVerify = true, verificationWait = 100) => {
  const contractFactory = await ethers.getContractFactory(name);
  const contract = await contractFactory.deploy(...args);
  await contract.deployed();
  console.log(`${name}: ${contract.address}`);

  if (hre.network.name === "localhost" || !shouldVerify) return contract;

  console.log("Verifying...");
  await verify(contract.address, args, name, verificationWait);

  return contract;
};

const tokenUri = "";

async function main() {
  const [deployer] = await ethers.getSigners();

  const chief = await deploy("NFTVillageChief");
  const feeReceiver = await deploy("NFTVillageChiefFeeReceiver");
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
  const projectHandler = await deploy("ProjectHandler", projectHandlerArgs);
  const cardHandlerArgs = [chief.address];
  const cardhandler = await deploy("CardHandler", cardHandlerArgs);

  await chief.connect(deployer).setProjectAndCardHandler(projectHandler.address, cardhandler.address);
  console.log(`NFTVillageChief: Project And Card Handler updated!`);

  const poolCardsArgs = ["NFTVillageCards", "NFTV", tokenUri];
  const poolCards = await deploy("NFTVillageERC1155", poolCardsArgs);

  const rewardTokenArgs = ["NFTVillageERC20"];
  const rewardToken = await deploy("TestToken", rewardTokenArgs);

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

  await sleep(100);

  await (await projectHandler.connect(deployer).initializeProject(0)).wait();
  console.log("Project Initialized");

  await (await rewardToken.approve(chief.address, constants.MaxUint256)).wait();
  console.log("Approved");

  await (await chief.depositRewardToken(0, 0, 0, utils.parseEther("100000000"))).wait();
  console.log("Tokens deposited");

  await (await rewardToken.transfer(PROJECT_ADMIN, utils.parseEther("10000"))).wait();
  console.log("transfered");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
