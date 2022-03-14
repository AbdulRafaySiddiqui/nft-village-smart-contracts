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
let user = "0x48656596EF052DA66c93830E2eD5BB7785f3C752";
let user2 = "0x283070d8D9ff69fCC9f84afE7013C1C32Fd5A19F";
let user3 = "0x97e54D0e19C6e457e392727b3F1C556b26C2178B";

const tokenUri =
  "https://metaflokirush.mypinata.cloud/ipfs/QmPJqw9DaUD7Dv5QUEmV9TgvMtiRhEVxupqGuduX3ha1gr/0x200D429421c53d75f0f9E4f92bC048c40915a9aa/{id}";

// Common
const getCommon = () => [
  { tokenId: 0, chest: 75, sale: 35 },
  { tokenId: 1, chest: 75, sale: 35 },
  { tokenId: 2, chest: 75, sale: 35 },
  { tokenId: 3, chest: 80, sale: 40 },
  { tokenId: 4, chest: 54, sale: 27 },
];
// Rare
const getRare = () => [
  { tokenId: 5, chest: 54, sale: 27 },
  { tokenId: 6, chest: 54, sale: 27 },
  { tokenId: 7, chest: 53, sale: 29 },
  { tokenId: 8, chest: 40, sale: 12 },
];
// Super Rare
const getSuperRare = () => [
  { tokenId: 9, chest: 40, sale: 12 },
  { tokenId: 10, chest: 45, sale: 11 },
  { tokenId: 11, chest: 12, sale: 4 },
];
// Epic
const getEpic = () => [
  { tokenId: 12, chest: 12, sale: 4 },
  { tokenId: 13, chest: 12, sale: 5 },
];
// Legendary
const getLegendary = () => [{ tokenId: 14, chest: 4, sale: 11 }];

// rare special
const getRareSpecial = () => [{ tokenId: 15 }];

// super rare special
const getSuperRareSpecial = () => [{ tokenId: 16 }, { tokenId: 17 }];

const COMMON_REWARD = utils.parseUnits("3000", 9);
const RARE_REWARD = utils.parseUnits("3000", 9);
const SUPER_RARE_REWARD = utils.parseUnits("4000", 9);
const EPIC_REWARD = utils.parseUnits("10000", 9);
const LEGENDARY_REWARD = utils.parseUnits("10000", 9);

const SPECIAL_RARE_REWARD = utils.parseUnits("3000", 9);
const SPECIAL_SUPER_RARE_REWARD = utils.parseUnits("4000", 9);

const TOKEN_REWARD = utils.parseUnits("3000", 9);

const getRewardInfo = (rewardToken, rewardPerBlock) => {
  return [
    {
      paused: false,
      mintable: false,
      lastRewardBlock: 0,
      accRewardPerShare: 0,
      supply: 0,
      token: rewardToken,
      rewardPerBlock: rewardPerBlock,
    },
  ];
};

async function main() {
  //Deploy contracts
  const [deployer] = await ethers.getSigners();
  user = deployer.address;

  const chiefContract = await ethers.getContractFactory("NFTVillageChief");
  // const chief = await chiefContract.deploy();
  const chief = await chiefContract.attach("0x9070334e4E2eF6aBf72a5b1E6B16D0b00b7e8EbA");
  console.log(`NFTVillageChief: ${chief.address}`);

  const feeReceiverContract = await ethers.getContractFactory("NFTVillageChiefFeeReceiver");
  // const feeReceiver = await feeReceiverContract.deploy();
  const feeReceiver = await feeReceiverContract.attach("0xd836Ba91fd50f9367e3625Ca254DA7918DB484A0");
  console.log(`NFTVillageChiefFeeReceiver: ${feeReceiver.address}`);

  const projectHandlerContract = await ethers.getContractFactory("ProjectHandler");
  // const projectHandler = await projectHandlerContract.deploy(
  //   chief.address,
  //   deployer.address,
  //   PROJECT_FEE,
  //   POOL_FEE,
  //   REWARD_FEE,
  //   feeReceiver.address,
  //   feeReceiver.address,
  //   feeReceiver.address
  // );
  const projectHandler = await projectHandlerContract.attach("0x9962fdA9cb6B0D20A05B20Bf170A6d4fA928b27f");
  console.log(`ProjectHandler: ${projectHandler.address}`);

  const cardHandlerContract = await ethers.getContractFactory("CardHandler");
  // cardhandler = await cardHandlerContract.deploy(chief.address);
  cardhandler = await cardHandlerContract.attach("0x699183bCA2a550A582014455b024173Bd71fD1Cc");
  console.log(`CardHandler: ${cardhandler.address}`);

  // await chief.connect(deployer).setProjectAndCardHandler(projectHandler.address, cardhandler.address);
  console.log(`NFTVillageChief: Project And Card Handler updated!`);

  const poolcardsContract = await ethers.getContractFactory("NFTVillageERC1155");
  //   const poolCards = await poolcardsContract.deploy("NFTVillageCards", "NFTV", tokenUri);
  // const poolCards = await poolcardsContract.attach("0x3E825dE61BEE268f46bD8F523f5F96D72bD4Fd89");
  // console.log(`NFTVillageERC1155: ${poolCards.address}`);

  // const testTokenContract = await ethers.getContractFactory("TestToken");
  // const rewardToken = await testTokenContract.deploy("MetaFlokiRush");
  // // // const rewardToken = await testTokenContract.attach("0x9e3B3927a11d4a136adf627888A9035DEfB0DA83");
  // console.log(`NFTVillageToken: ${rewardToken.address}`);

  const rewardToken = { address: "0x2f800cBdDA851b5df3A1C9E629538E49BB9547FF" };
  // console.log(`Mint tokens`);
  // await (await rewardToken.mint(user, utils.parseEther("100000000"))).wait();
  // await (await rewardToken.mint(user2, utils.parseEther("100000000"))).wait();
  // await (await rewardToken.mint(user3, utils.parseEther("100000000"))).wait();

  pool = {
    stakedToken: ZERO_ADDRESS,
    lockDeposit: false,
    stakedAmount: 0,
    totalShares: 0,
    depositFee: 0,
    minWithdrawlFee: 0,
    maxWithdrawlFee: 0,
    withdrawlFeeReliefInterval: 0,
    minDeposit: MIN_DEPOSIT,
    harvestInterval: 604800,
    stakedTokenStandard: 3, //  TokenStandard.NONE
    stakedTokenId: 0,
    minRequiredCards: 1,
  };

  //   const tokenIds = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 13, 14, 15];
  //   for (let i = 0; i < tokenIds.length; i++) {
  //     const e = tokenIds[i];
  //     await (await poolCards.addMultiplierCard(e, 100 * i + 1)).wait();
  //     console.log("added ", e);
  //   }
  // await (
  //   await poolCards.mintBatch(
  //     user3,
  //     tokenIds,
  //     tokenIds.map((e) => 100),
  //     [[]]
  //   )
  // ).wait();
  // await (
  //   await poolCards.mintBatch(
  //     user,
  //     tokenIds,
  //     tokenIds.map((e) => 100),
  //     [[]]
  //   )
  // ).wait();
  // console.log("Require Cards Minted");

  // const { provider } = ethers;
  // const block = await provider.getBlockNumber();
  // await (
  //   await projectHandler
  //     .connect(deployer)
  //     .addProject(deployer.address, 0, 0, block, poolCards.address, { value: PROJECT_FEE })
  // ).wait();
  // console.log("Project Added");

  // common
  // await (
  //   await projectHandler.connect(deployer).setPool(
  //     0,
  //     0,
  //     pool,
  //     getRewardInfo(rewardToken.address, COMMON_REWARD),
  //     // getCommon().map((e) => {
  //     //   return { tokenId: e.tokenId, amount: 1 };
  //     // }),
  //     { value: POOL_FEE }
  //   )
  // ).wait();
  // rare
  // await (
  //   await projectHandler.connect(deployer).setPool(
  //     0,
  //     1,
  //     pool,
  //     getRewardInfo(rewardToken.address, RARE_REWARD),
  //     // getRare().map((e) => {
  //     //   return { tokenId: e.tokenId, amount: 1 };
  //     // }),
  //     { value: POOL_FEE }
  //   )
  // ).wait();
  // // super rare
  // await (
  //   await projectHandler.connect(deployer).setPool(
  //     0,
  //     2,
  //     pool,
  //     getRewardInfo(rewardToken.address, SUPER_RARE_REWARD),
  //     // getSuperRare().map((e) => {
  //     //   return { tokenId: e.tokenId, amount: 1 };
  //     // }),
  //     { value: POOL_FEE }
  //   )
  // ).wait();
  // // epic
  // await (
  //   await projectHandler.connect(deployer).setPool(
  //     0,
  //     3,
  //     pool,
  //     getRewardInfo(rewardToken.address, EPIC_REWARD),
  //     // getEpic().map((e) => {
  //     //   return { tokenId: e.tokenId, amount: 1 };
  //     // }),
  //     { value: POOL_FEE }
  //   )
  // ).wait();
  // // legendary
  // await (
  //   await projectHandler.connect(deployer).setPool(
  //     0,
  //     4,
  //     pool,
  //     getRewardInfo(rewardToken.address, LEGENDARY_REWARD),
  //     // getLegendary().map((e) => {
  //     //   return { tokenId: e.tokenId, amount: 1 };
  //     // }),
  //     { value: POOL_FEE }
  //   )
  // ).wait();

  // // ukrain nft
  // await (
  //   await projectHandler.connect(deployer).setPool(
  //     0,
  //     5,
  //     pool,
  //     getRewardInfo(rewardToken.address, SPECIAL_RARE_REWARD),
  //     // getRareSpecial().map((e) => {
  //     //   return { tokenId: e.tokenId, amount: 1 };
  //     // }),
  //     { value: POOL_FEE }
  //   )
  // ).wait();

  // // special super rare
  // await (
  //   await projectHandler.connect(deployer).setPool(
  //     0,
  //     6,
  //     pool,
  //     getRewardInfo(rewardToken.address, SPECIAL_SUPER_RARE_REWARD),
  //     // getSuperRareSpecial().map((e) => {
  //     //   return { tokenId: e.tokenId, amount: 1 };
  //     // }),
  //     { value: POOL_FEE }
  //   )
  // ).wait();

  // tokenPool = {
  //   stakedToken: rewardToken.address,
  //   lockDeposit: false,
  //   stakedAmount: 0,
  //   totalShares: 0,
  //   depositFee: 0,
  //   minWithdrawlFee: 0,
  //   maxWithdrawlFee: 0,
  //   withdrawlFeeReliefInterval: 0,
  //   minDeposit: MIN_DEPOSIT,
  //   harvestInterval: 604800,
  //   stakedTokenStandard: 0,
  //   stakedTokenId: 0,
  //   minRequiredCards: 0,
  // };

  // await (
  //   await projectHandler
  //     .connect(deployer)
  //     .setPool(0, 7, tokenPool, getRewardInfo(rewardToken.address, TOKEN_REWARD), { value: POOL_FEE })
  // ).wait();
  // console.log("Pools Added");

  //   await (await projectHandler.connect(deployer).initializeProject(0)).wait();
  //   console.log("Project Initialized");

  // for test
  // await (await rewardToken.approve(chief.address, constants.MaxUint256)).wait();
  // console.log("approved");
  // await (await poolCards.setApprovalForAll(cardhandler.address, true)).wait();
  // console.log("pool cards approved");
  // await (
  //   await chief.deposit(
  //     0,
  //     0,
  //     utils.parseEther("100"),
  //     feeCards.slice(0, 1),
  //     feeCards.slice(1, feeCards.length - 1),
  //     harvestCards,
  //     multiplierCards,
  //     [{ tokenId: 0, amount: 1 }],
  //     ZERO_ADDRESS
  //   )
  // ).wait();

  // console.log("deposite success");

  // await (await chief.depositRewardToken(0, 7, 0, utils.parseEther("1000000"))).wait();
  // await (await chief.depositRewardToken(0, 1, 0, utils.parseEther("1000000"))).wait();

  // console.log("deposited reward tokens");

  // await chief.withdraw(0, 0, 1);

  // console.log(await chief.userInfo(0, 0, deployer.address));

  const tokenContract = await ethers.getContractFactory("TestToken");
  const token = await tokenContract.attach(rewardToken.address);
  await (await token.approve(chief.address, constants.MaxUint256)).await();
  console.log("approved");

  await (await chief.depositRewardToken(0, 0, 0, COMMON_REWARD.mul(1000))).wait();
  console.log("0");
  await (await chief.depositRewardToken(0, 1, 0, RARE_REWARD.mul(1000))).wait();
  console.log("1");
  await (await chief.depositRewardToken(0, 2, 0, SUPER_RARE_REWARD.mul(1000))).wait();
  console.log("2");
  await (await chief.depositRewardToken(0, 3, 0, EPIC_REWARD.mul(1000))).wait();
  console.log("3");
  await (await chief.depositRewardToken(0, 4, 0, LEGENDARY_REWARD.mul(1000))).wait();
  console.log("4");
  await (await chief.depositRewardToken(0, 5, 0, SPECIAL_RARE_REWARD.mul(1000))).wait();
  console.log("5");
  await (await chief.depositRewardToken(0, 6, 0, SPECIAL_SUPER_RARE_REWARD.mul(1000))).wait();
  console.log("6");
  await (await chief.depositRewardToken(0, 7, 0, TOKEN_REWARD.mul(1000))).wait();
  console.log("7");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
