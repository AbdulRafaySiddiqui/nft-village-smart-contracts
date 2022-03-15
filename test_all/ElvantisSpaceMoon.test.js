const { ethers, waffle } = require("hardhat");
const { expect, use } = require("chai");
const { solidity } = require("ethereum-waffle");
const { BigNumber, utils, provider } = ethers;

use(solidity);

const sleep = async (s) => {
  for (let i = s; i > 0; i--) {
    process.stdout.write(`\r \\ ${i} waiting..`)
    await new Promise(resolve => setTimeout(resolve, 250));
    process.stdout.write(`\r | ${i} waiting..`)
    await new Promise(resolve => setTimeout(resolve, 250));
    process.stdout.write(`\r / ${i} waiting..`)
    await new Promise(resolve => setTimeout(resolve, 250));
    process.stdout.write(`\r - ${i} waiting..`)
    await new Promise(resolve => setTimeout(resolve, 250));
    if (i === 1) {
      process.stdout.clearLine();
      process.stdout.cursorTo(0);
    }
  }
}

const ZERO = new BigNumber.from("0");
const ONE = new BigNumber.from("1");
const ONE_ETH = utils.parseEther("1");
const LESS_ETH = utils.parseEther("0.0001");
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const MAX_UINT = "115792089237316195423570985008687907853269984665640564039457584007913129639935";

const PROJECT_FEE = utils.parseEther("2");
const POOL_FEE = utils.parseEther("1");
const REWARD_FEE = "500"; // 5%
const REFERRAL_FEE = "0"; // 5%
const REWARD_PER_BLOCK = utils.parseEther("1");
const MIN_DEPOSIT = utils.parseEther("1")

let elvantisSpaceMoon, stakeToken, rewardToken, elvantisPoolcards;
let owner, projectOwner, user1, user2, user3, user4;
let projectId = 0;
let poolId = 0;
let pool;
let rewardInfo = [];
let requiredCards = []; let multiplierCards = []; let harvestCards = []; let feeCards = []
let depositedAmount = utils.parseEther('1')
let cardhandler, projectHandler;
const MULTIPLIER_2X_ID = 5;
const MULTIPLIER_3X_ID = 7;
const FEE_DISCOUNT_10_ID = 12;
const FEE_DISCOUNT_100_ID = 14;
const HARVEST_RELIEF_1_HOUR_ID = 8;

describe("ElvantisSpaceMoon Tests", () => {
  it("It should deploy ElvantisSpaceMoon, staketoken & rewardtoken", async () => {
    [owner, projectOwner, user1, user2, user3] = await ethers.getSigners();

    const elvantisSpaceMoonContract = await ethers.getContractFactory("ElvantisSpaceMoon");
    elvantisSpaceMoon = await elvantisSpaceMoonContract.deploy();

    const feeReceiverContract = await ethers.getContractFactory("ElvantisSpaceMoonFeeReceiver");
    feeReceiver = await feeReceiverContract.deploy();

    const projectHandlerContract = await ethers.getContractFactory("ProjectHandler");
    projectHandler = await projectHandlerContract.deploy(elvantisSpaceMoon.address, owner.address, PROJECT_FEE, POOL_FEE, REWARD_FEE, feeReceiver.address, feeReceiver.address, feeReceiver.address);

    const cardHandlerContract = await ethers.getContractFactory("CardHandler");
    cardhandler = await cardHandlerContract.deploy(elvantisSpaceMoon.address,);

    await elvantisSpaceMoon.setProjectAndCardHandler(projectHandler.address, cardhandler.address);

    const poolcardsContract = await ethers.getContractFactory("ElvantisPoolCards");
    elvantisPoolcards = await poolcardsContract.deploy();

    const stakeContract = await ethers.getContractFactory("StakeToken");
    stakeToken = await stakeContract.deploy();

    const rewardContract = await ethers.getContractFactory("Elvantis");
    rewardToken = await rewardContract.deploy(owner.address, owner.address);

    await stakeToken.mint(user1.address, utils.parseEther("1"))
    await stakeToken.mint(user2.address, utils.parseEther("1"))

    // await rewardToken.setMinter(elvantisSpaceMoon.address);

    pool = {
      stakedToken: stakeToken.address,
      lockDeposit: true,
      stakedAmount: 0,
      totalShares: 0,
      depositFee: 0,
      minWithdrawlFee: 1000,
      maxWithdrawlFee: 1000,
      withdrawlFeeReliefInterval: 0,
      minDeposit: MIN_DEPOSIT,
      harvestInterval: 2,
      stakedTokenStandard: 0,
      stakedTokenId: 0,
    }

    rewardInfo.push({
      paused: false,
      mintable: false,
      excludeFee: true,
      lastRewardBlock: 0,
      accRewardPerShare: 0,
      supply: 0,
      token: rewardToken.address,
      rewardPerBlock: REWARD_PER_BLOCK,
    },
    )

  });

  it('It should mint Cards for pool', async () => {
    let tokenIdToMint = await elvantisPoolcards.nextTokenId();
    elvantisPoolcards.mint(user1.address, tokenIdToMint, 1)
    elvantisPoolcards.mint(user2.address, tokenIdToMint, 1)
    elvantisPoolcards.mint(user3.address, tokenIdToMint, 1)
    requiredCards.push({ tokenId: tokenIdToMint, amount: 1 });

    tokenIdToMint = await elvantisPoolcards.nextTokenId();
    elvantisPoolcards.mint(user1.address, tokenIdToMint, 1)
    elvantisPoolcards.mint(user2.address, tokenIdToMint, 1)
    elvantisPoolcards.mint(user3.address, tokenIdToMint, 1)
    requiredCards.push({ tokenId: tokenIdToMint, amount: 1 });

    const _harvestCards = await elvantisPoolcards.getHarvestReliefCards();
    const _feediscount = await elvantisPoolcards.getFeeDiscountCards();
    const _multiplier = await elvantisPoolcards.getMultiplierCards();
    for (let i = 0; i < _harvestCards.length; i++) {
      await elvantisPoolcards.mint(user1.address, _harvestCards[i], 1)
      harvestCards.push({ tokenId: _harvestCards[i], amount: 1 })
    }
    for (let i = 0; i < _feediscount.length; i++) {
      await elvantisPoolcards.mint(user1.address, _feediscount[i], 1)
      feeCards.push({ tokenId: _feediscount[i], amount: 1 })

    }
    for (let i = 0; i < _multiplier.length; i++) {
      await elvantisPoolcards.mint(user1.address, _multiplier[i], 1)
      multiplierCards.push({ tokenId: _multiplier[i], amount: 1 })
    }
  })

  it('It should fail to add project with revert message', async () => {
    const block = await provider.getBlockNumber()
    await expect(projectHandler.connect(projectOwner).addProject(projectOwner.address, 1000, REFERRAL_FEE, block, ZERO_ADDRESS))
      .to
      .revertedWith('ProjectHandler: Invalid Project Fee!')
    await expect(projectHandler.connect(projectOwner).addProject(projectOwner.address, 1000, REFERRAL_FEE, block, ZERO_ADDRESS), { value: utils.parseEther('3') })
      .to
      .revertedWith('ProjectHandler: Invalid Project Fee!')
  })

  it("It should add a project and charge project Fee", async () => {
    const block = await provider.getBlockNumber()
    const initialBalance = await provider.getBalance(owner.address);
    await projectHandler.connect(projectOwner).addProject(projectOwner.address, 1000, REFERRAL_FEE, block, elvantisPoolcards.address, { value: PROJECT_FEE })
    const finalBalance = await provider.getBalance(owner.address);

    expect(finalBalance.sub(initialBalance)).to.deep.equal(PROJECT_FEE);
  })

  it('It should fail to add pool and revert with message', async () => {
    await expect(projectHandler.connect(projectOwner).addPool(projectId, pool, rewardInfo, []))
      .to
      .revertedWith('ProjectHandler: Invalid Pool Fee!')
  })

  it('It should add pool and charge pool fee', async () => {
    const initialBalance = await provider.getBalance(owner.address);
    await projectHandler.connect(projectOwner).addPool(projectId, pool, rewardInfo, requiredCards, { value: POOL_FEE })
    const finalBalance = await provider.getBalance(owner.address);

    expect(finalBalance.sub(initialBalance)).to.deep.equal(POOL_FEE);
  })

  it('It should not allow to stake in pool', async () => {
    await stakeToken.connect(user1).approve(elvantisSpaceMoon.address, ethers.constants.MaxUint256);
    await expect(elvantisSpaceMoon.connect(user1).deposit(projectId, poolId, depositedAmount, [], [], [], [], ZERO_ADDRESS))
      .to.revertedWith('ElvantisSpaceMoon: Project paused!')
    await projectHandler.connect(projectOwner).initializeProject(projectId);
    await expect(elvantisSpaceMoon.connect(user1).deposit(projectId, poolId, depositedAmount, [], [], [], [], ZERO_ADDRESS))
      .to.revertedWith('ElvantisSpaceMoon: Deposit locked!')
    pool.lockDeposit = false; // allow deposit
    await projectHandler.connect(projectOwner).setPool(projectId, poolId, pool, rewardInfo);
    await expect(elvantisSpaceMoon.connect(user1).deposit(projectId, poolId, utils.parseEther('0.1'), [], [], [], [], ZERO_ADDRESS))
      .to.revertedWith('ElvantisSpaceMoon: Deposit amount too low!')

    await rewardToken.connect(owner).approve(elvantisSpaceMoon.address, await rewardToken.balanceOf(owner.address))
  })

  it('It should allow user 1 to stake in pool', async () => {
    await stakeToken.connect(user1).approve(elvantisSpaceMoon.address, ethers.constants.MaxUint256);
    await elvantisPoolcards.connect(user1).setApprovalForAll(cardhandler.address, true);
    await expect(elvantisSpaceMoon.connect(user1)
      .deposit(
        projectId,
        poolId,
        depositedAmount,
        feeCards.slice(0, 1),
        feeCards.slice(1, feeCards.length - 1),
        harvestCards,
        [{ tokenId: MULTIPLIER_3X_ID, amount: 1 }], ZERO_ADDRESS)
    )
      .to.emit(elvantisSpaceMoon, 'Deposit')
  })

  it('It should allow user 2 to stake in pool', async () => {
    await stakeToken.connect(user2).approve(elvantisSpaceMoon.address, ethers.constants.MaxUint256);
    await elvantisPoolcards.connect(user2).setApprovalForAll(cardhandler.address, true);
    await expect(elvantisSpaceMoon.connect(user2)
      .deposit(
        projectId,
        poolId,
        depositedAmount,
        [],
        [],
        [],
        [], ZERO_ADDRESS)
    )
      .to.emit(elvantisSpaceMoon, 'Deposit')
  })

  it("It should have user1 rewards 3 times greater than user 2 rewards", async () => {
    await rewardToken.mint(owner.address, utils.parseEther("100000"))
    await rewardToken.approve(elvantisSpaceMoon.address, utils.parseEther("100000"))
    await elvantisSpaceMoon.depositRewardToken(projectId, poolId, 0, utils.parseEther("100"))

    let user1RewardBefore = await elvantisSpaceMoon.pendingRewards(projectId, poolId, user1.address)
    user1RewardBefore = user1RewardBefore[0];
    let user2RewardBefore = await elvantisSpaceMoon.pendingRewards(projectId, poolId, user2.address)
    user2RewardBefore = user2RewardBefore[0];

    // mine a block, so user 2 pending rewards can be increased
    await elvantisSpaceMoon.updatePool(projectId, poolId)

    let user1Reward = await elvantisSpaceMoon.pendingRewards(projectId, poolId, user1.address)
    let user2Reward = await elvantisSpaceMoon.pendingRewards(projectId, poolId, user2.address)
    user1Reward = user1Reward[0]
    user2Reward = user2Reward[0]

    // subtract rewards from previously mined 3 blocks since deposit, so both users unclaimed reward are on block
    user1Reward = user1Reward.sub(user1RewardBefore)
    user2Reward = user2Reward.sub(user2RewardBefore)

    // both users have deposited same amount, but user 1 has a multiplier of 3X (means 200% increase rewards from pool)
    // so users1 & user2 share the reward pool in ratio of 3:1
    expect(user1Reward).to.deep.equal(REWARD_PER_BLOCK.mul(75).div(100))
    expect(user2Reward).to.deep.equal(REWARD_PER_BLOCK.mul(25).div(100))
  })

  it('It should increase user2 shares', async () => {
    await elvantisPoolcards.mint(user2.address, MULTIPLIER_2X_ID, 1)
    const userInfoBefore = await elvantisSpaceMoon.userInfo(projectId, poolId, user2.address)
    await elvantisSpaceMoon.connect(user2).deposit(projectId, poolId, 0, [], [], [], [{ tokenId: MULTIPLIER_2X_ID, amount: 1 }], ZERO_ADDRESS)
    const userInfo = await elvantisSpaceMoon.userInfo(projectId, poolId, user2.address)

    const multiplier = await elvantisPoolcards.getMultiplier(MULTIPLIER_2X_ID)

    expect(userInfo.shares).to.deep.equal(userInfoBefore.shares.add(userInfoBefore.amount.mul(multiplier).div(10000)))
  })

  it('It should decrease user2 shares', async () => {
    const userInfoBefore = await elvantisSpaceMoon.userInfo(projectId, poolId, user2.address)
    await elvantisSpaceMoon.connect(user2).withdrawMultiplierCard(projectId, poolId, [{ tokenId: MULTIPLIER_2X_ID, amount: 1 }])
    const userInfo = await elvantisSpaceMoon.userInfo(projectId, poolId, user2.address)

    const multiplier = await elvantisPoolcards.getMultiplier(MULTIPLIER_2X_ID)

    expect(userInfo.shares).to.deep.equal(userInfoBefore.shares.sub(userInfo.amount.mul(multiplier).div(10000)))
  })

  it("It should charge 5% deposit fee", async () => {
    pool.depositFee = 500
    await projectHandler.connect(projectOwner).setPool(projectId, poolId, pool, rewardInfo)
    stakeToken.mint(user3.address, utils.parseEther("1"))
    const despositAmount = utils.parseEther("1");

    await elvantisPoolcards.mint(user3.address, FEE_DISCOUNT_10_ID, 1)

    await stakeToken.connect(user3).approve(elvantisSpaceMoon.address, ethers.constants.MaxUint256);
    await elvantisPoolcards.connect(user3).setApprovalForAll(cardhandler.address, true);
    await expect(elvantisSpaceMoon.connect(user3)
      .deposit(
        projectId,
        poolId,
        despositAmount,
        [],
        [{ tokenId: FEE_DISCOUNT_10_ID, amount: 1 }],
        [],
        [],
        ZERO_ADDRESS)
    ).to.emit(elvantisSpaceMoon, 'Deposit')

    const userInfo = await elvantisSpaceMoon.userInfo(projectId, poolId, user3.address)
    expect(userInfo.amount).to.deep.equal(despositAmount.sub(despositAmount.mul(pool.depositFee).div(10000)))
  })

  it("It should give fee discount on deposit", async () => {
    const userInfoBefore = await elvantisSpaceMoon.userInfo(projectId, poolId, user3.address)
    stakeToken.mint(user3.address, utils.parseEther("1"))
    const despositAmount = utils.parseEther("1");
    await elvantisPoolcards.mint(user3.address, FEE_DISCOUNT_10_ID, 1)

    await expect(elvantisSpaceMoon.connect(user3)
      .deposit(
        projectId,
        poolId,
        despositAmount,
        [{ tokenId: FEE_DISCOUNT_10_ID, amount: 1 }],
        [],
        [],
        [],
        ZERO_ADDRESS)
    ).to.emit(elvantisSpaceMoon, 'Deposit')

    const userInfo = await elvantisSpaceMoon.userInfo(projectId, poolId, user3.address)
    const amount = userInfo.amount.sub(userInfoBefore.amount)
    const depositFeeDiscount = await elvantisPoolcards.getFeeDiscount(FEE_DISCOUNT_10_ID)
    const depositFee = BigNumber.from(pool.depositFee).sub(BigNumber.from(pool.depositFee).mul(depositFeeDiscount).div(10000))
    expect(amount).to.deep.equal(despositAmount.sub(despositAmount.mul(depositFee).div(10000)))
  })

  it("It should validate harvesting interval", async () => {
    await elvantisSpaceMoon.connect(user3).deposit(projectId, poolId, 0, [], [], [], [], ZERO_ADDRESS)
    expect(await elvantisSpaceMoon.canHarvest(projectId, poolId, user3.address)).to.eq(false)

    await sleep(pool.harvestInterval - 1) // subtract 1 second for delay
    // mine block to increase timestamp
    await elvantisSpaceMoon.updatePool(projectId, poolId)

    expect(await elvantisSpaceMoon.canHarvest(projectId, poolId, user3.address)).to.eq(true)
  })

  it('It should give harvest relief', async () => {
    const blockDataBefore = await provider.getBlock(await provider.getBlockNumber());
    await elvantisSpaceMoon.connect(user3).deposit(projectId, poolId, 0, [], [], [], [], ZERO_ADDRESS)
    const userInfoBefore = await elvantisSpaceMoon.userInfo(projectId, poolId, user3.address)

    expect(userInfoBefore.nextHarvestUntil)
      .to.deep.equal(BigNumber.from(blockDataBefore.timestamp + 1).add(pool.harvestInterval))

    pool.harvestInterval = 600
    await projectHandler.connect(projectOwner).setPool(projectId, poolId, pool, rewardInfo)

    await elvantisPoolcards.mint(user3.address, HARVEST_RELIEF_1_HOUR_ID, 1)
    const blockData = await provider.getBlock(await provider.getBlockNumber());
    await elvantisSpaceMoon.connect(user3).deposit(projectId, poolId, 0, [], [], [{ tokenId: HARVEST_RELIEF_1_HOUR_ID, amount: 1 }], [], ZERO_ADDRESS)
    const userInfo = await elvantisSpaceMoon.userInfo(projectId, poolId, user3.address)

    const harvestRelief = await elvantisPoolcards.getHarvestRelief(HARVEST_RELIEF_1_HOUR_ID);

    expect(userInfo.nextHarvestUntil)
      .to.deep.equal(BigNumber.from(blockData.timestamp + 1).add(pool.harvestInterval).sub(harvestRelief))
  })

  it("It should harvest tokens", async () => {
    const balanceBefore = await rewardToken.balanceOf(user1.address);
    await elvantisSpaceMoon.connect(user1).deposit(projectId, poolId, 0, [], [], [], [], ZERO_ADDRESS)
    const balanceAfter = await rewardToken.balanceOf(user1.address);

    expect(balanceAfter).to.gt(balanceBefore)
  })

  it('It should give withdraw fee discount', async () => {
    await elvantisSpaceMoon.connect(user3).deposit(projectId, poolId, 0, [], [], [], [], ZERO_ADDRESS)
    const userInfo = await elvantisSpaceMoon.userInfo(projectId, poolId, user3.address)
    const balanceBefore = await stakeToken.balanceOf(user3.address);
    await expect(elvantisSpaceMoon.connect(user3).withdraw(projectId, poolId, userInfo.amount))
      .to.emit(elvantisSpaceMoon, 'Withdraw')
    const balance = await stakeToken.balanceOf(user3.address);
    const feeDiscount = await elvantisPoolcards.getFeeDiscount(FEE_DISCOUNT_10_ID);

    const withdrawFee = userInfo.amount.mul(1000).div(10000);
    expect(balance.sub(balanceBefore))
      .to.deep.equal(userInfo.amount.sub(withdrawFee.sub(withdrawFee.mul(feeDiscount).div(10000))))
  })

  it("It should withdraw", async () => {
    const userInfo = await elvantisSpaceMoon.userInfo(projectId, poolId, user1.address)
    await expect(elvantisSpaceMoon.connect(user1).withdraw(projectId, poolId, userInfo.amount))
      .to.emit(elvantisSpaceMoon, 'Withdraw')
  })

  it('It should charge withdraw fee', async () => {
    const userInfo = await elvantisSpaceMoon.userInfo(projectId, poolId, user2.address)
    const balanceBefore = await stakeToken.balanceOf(user2.address);
    await expect(elvantisSpaceMoon.connect(user2).withdraw(projectId, poolId, userInfo.amount))
      .to.emit(elvantisSpaceMoon, 'Withdraw')
    const balance = await stakeToken.balanceOf(user2.address);
    expect(balance.sub(balanceBefore))
      .to.deep.equal(userInfo.amount.sub(userInfo.amount.mul(1000).div(10000)))
  })


  it('It should not charge withdraw fee after withdraw interval relief period', async () => {
    pool.minWithdrawlFee = 0;
    pool.withdrawlFeeReliefInterval = 4;
    await projectHandler.connect(projectOwner).setPool(projectId, poolId, pool, rewardInfo);

    const balanceBefore = await stakeToken.balanceOf(user3.address);
    await elvantisSpaceMoon.connect(user3).deposit(projectId, poolId, balanceBefore, [], [], [], [], ZERO_ADDRESS)
    const userInfo = await elvantisSpaceMoon.userInfo(projectId, poolId, user3.address)

    await sleep(4);

    await elvantisSpaceMoon.updatePool(projectId, poolId)

    await expect(elvantisSpaceMoon.connect(user3).withdraw(projectId, poolId, userInfo.amount))
      .to.emit(elvantisSpaceMoon, 'Withdraw')

    const balance = await stakeToken.balanceOf(user3.address);

    expect(balance).to.deep.equal(userInfo.amount)
  })

  it('It should charge half withdraw fee as half withdraw time period has passed', async () => {
    const balanceBefore = await stakeToken.balanceOf(user3.address);
    await elvantisSpaceMoon.connect(user3).deposit(projectId, poolId, balanceBefore, [], [], [], [], ZERO_ADDRESS)
    const userInfo = await elvantisSpaceMoon.userInfo(projectId, poolId, user3.address)

    await sleep(2);

    await elvantisSpaceMoon.updatePool(projectId, poolId)

    await expect(elvantisSpaceMoon.connect(user3).withdraw(projectId, poolId, userInfo.amount))
      .to.emit(elvantisSpaceMoon, 'Withdraw')

    const balance = await stakeToken.balanceOf(user3.address);

    const feeRelief = BigNumber.from(3) // use 3 seconds here as stakedTime period
      .mul(10000000).div(pool.withdrawlFeeReliefInterval).mul(1000).div(10000000);
    const withdrawFee = BigNumber.from(pool.maxWithdrawlFee).sub(feeRelief);

    expect(balance).to.deep.equal(userInfo.amount.sub(userInfo.amount.mul(withdrawFee).div(10000)))
  })

});