const { utils, constants } = require('ethers')
const { ethers } = require('hardhat')
const hre = require('hardhat')

const ROUTERS = {
    PANCAKE: '0x10ED43C718714eb63d5aA57B78B54704E256024E',
    PANCAKE_TESTNET: '0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3',
    UNISWAP: '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D',
    SUSHISWAP_TESTNET: '0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506',
    PANGALIN: '0xE54Ca86531e17Ef3616d22Ca28b0D458b6C89106'
}

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
        if (i === 1) process.stdout.clearLine();
    }
}
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

const PROJECT_FEE = utils.parseEther("0");
const POOL_FEE = utils.parseEther("0");
const REWARD_FEE = "0"; // 5%
const REWARD_PER_BLOCK = utils.parseEther("1");
const MIN_DEPOSIT = utils.parseEther("0")

let pool
const rewardInfo = []
const harvestCards = []
const multiplierCards = []
const feeCards = []
const requiredCards = []
let user = '0x48656596EF052DA66c93830E2eD5BB7785f3C752';
let user2 = '0x283070d8D9ff69fCC9f84afE7013C1C32Fd5A19F';
const tokenUri = ''

async function main() {
    //Deploy contracts
    const [deployer] = await ethers.getSigners()
    user = deployer.address;

    const chiefContract = await ethers.getContractFactory("NFTVillageChief");
    const chief = await chiefContract.deploy();
    console.log(`NFTVillageChief: ${chief.address}`)

    const feeReceiverContract = await ethers.getContractFactory("NFTVillageChiefFeeReceiver");
    const feeReceiver = await feeReceiverContract.deploy();
    console.log(`NFTVillageChiefFeeReceiver: ${feeReceiver.address}`)

    const projectHandlerContract = await ethers.getContractFactory("ProjectHandler");
    const projectHandler = await projectHandlerContract.deploy(chief.address, deployer.address, PROJECT_FEE, POOL_FEE, REWARD_FEE, feeReceiver.address, feeReceiver.address, feeReceiver.address);
    console.log(`ProjectHandler: ${projectHandler.address}`)

    const cardHandlerContract = await ethers.getContractFactory("CardHandler");
    cardhandler = await cardHandlerContract.deploy(chief.address);
    console.log(`CardHandler: ${cardhandler.address}`)

    await chief.connect(deployer).setProjectAndCardHandler(projectHandler.address, cardhandler.address);
    console.log(`NFTVillageChief: Project And Card Handler updated!`)

    const poolcardsContract = await ethers.getContractFactory("NFTVillageERC1155");
    const poolCards = await poolcardsContract.deploy('NFTVillageCards', 'NFTV',tokenUri);
    console.log(`NFTVillageERC1155: ${poolCards.address}`)

    const testTokenContract = await ethers.getContractFactory("TestToken");
    const testToken = await testTokenContract.deploy("NFTVillageToken");
    console.log(`NFTVillageToken: ${testToken.address}`)
    const testToken2 = await testTokenContract.deploy("NFTVillage Reward");
    console.log(`NFTVillage Test Token: ${testToken2.address}`)

    console.log(`Mint tokens`)
    await (await testToken.mint(user, utils.parseEther('100000000'))).wait()
    await (await testToken.mint(user2, utils.parseEther('100000000'))).wait()

    pool = {
        stakedToken: testToken.address,
        lockDeposit: false,
        stakedAmount: 0,
        totalShares: 0,
        depositFee: 0,
        minWithdrawlFee: 0,
        maxWithdrawlFee: 0,
        withdrawlFeeReliefInterval: 0,
        minDeposit: MIN_DEPOSIT,
        harvestInterval: 0,
        stakedTokenStandard: 0,
        stakedTokenId: 0,
        minRequiredCards: 1
    }

    rewardInfo.push({
        paused: false,
        mintable: false,
        lastRewardBlock: 0,
        accRewardPerShare: 0,
        supply: 0,
        token: testToken2.address,
        rewardPerBlock: REWARD_PER_BLOCK,
    })

    const tokenIds = [0];
    await (await poolCards.mintBatch(user, tokenIds, tokenIds.map(e => 100),[])).wait()
    tokenIds.forEach(e => requiredCards.push({ tokenId: e, amount: 1 }))
    console.log('Require Cards Minted 1')

    // tokenIdToMint = 0
    // await (await poolCards.mint(user, tokenIdToMint, 1)).wait()
    // requiredCards.push({ tokenId: tokenIdToMint, amount: 1 });
    // console.log('Require Cards Minted 2')

    // const _harvestCards = await poolCards.getHarvestReliefCards();
    // const _feediscount = await poolCards.getFeeDiscountCards();
    // const _multiplier = await poolCards.getMultiplierCards();
    // for (let i = 0; i < _harvestCards.length; i++) {
    //     await (await poolCards.mint(user, _harvestCards[i], 1)).wait()
    //     harvestCards.push({ tokenId: _harvestCards[i], amount: 1 })
    //     console.log(`Harvest Card Added: ${_harvestCards[i]}`)
    // }

    // for (let i = 0; i < _feediscount.length; i++) {
    //     await (await poolCards.mint(user, _feediscount[i], 1)).wait()
    //     feeCards.push({ tokenId: _feediscount[i], amount: 1 })
    //     console.log(`Fee Card Added: ${_feediscount[i]}`)
    // }
    // for (let i = 0; i < _multiplier.length; i++) {
    //     await (await poolCards.mint(user, _multiplier[i], 1)).wait()
    //     multiplierCards.push({ tokenId: _multiplier[i], amount: 1 })
    //     console.log(`Multiplier Card Added: ${_multiplier[i]}`)
    // }

    const { provider } = ethers
    const block = await provider.getBlockNumber()
    await (await projectHandler.connect(deployer).addProject(deployer.address, 0, 0, block, poolCards.address, { value: PROJECT_FEE })).wait()
    console.log('Project Added')
    await (await projectHandler.connect(deployer).addPool(0, pool, rewardInfo, requiredCards, { value: POOL_FEE })).wait()
    console.log('Pool 1 Added')
    rewardInfo.push({
        paused: false,
        mintable: false,
        lastRewardBlock: 0,
        accRewardPerShare: 0,
        supply: 0,
        token: testToken2.address,
        rewardPerBlock: REWARD_PER_BLOCK,
    })
    await (await projectHandler.connect(deployer).addPool(0, pool, rewardInfo, requiredCards, { value: POOL_FEE })).wait()
    console.log('Pool 2 Added')
    await (await projectHandler.connect(deployer).initializeProject(0)).wait()
    console.log('Project Initialized')

    // for test
    // await (await testToken.approve(chief.address, constants.MaxUint256)).wait(); console.log('approved')
    // await (await testToken2.approve(chief.address, constants.MaxUint256)).wait(); console.log('points approved')
    // await (await poolCards.setApprovalForAll(cardhandler.address, true)).wait(); console.log('pool cards approved')
    // await (await chief
    //     .deposit(
    //         0,
    //         0,
    //         utils.parseEther('100'),
    //         feeCards.slice(0, 1),
    //         feeCards.slice(1, feeCards.length - 1),
    //         harvestCards,
    //         multiplierCards,
    //         requiredCards,
    //         ZERO_ADDRESS
    //     )).wait()

    // console.log('deposite success')

    // await (await chief.depositRewardToken(0, 0, 0, utils.parseEther('1000000'))).wait()
    // await (await chief.depositRewardToken(0, 1, 0, utils.parseEther('1000000'))).wait()

    // console.log('deposited reward tokens')

    // console.log('deposit again')
    // await (await chief
    //     .deposit(
    //         0,
    //         0,
    //         utils.parseEther('100'),
    //         feeCards.slice(0, 1),
    //         feeCards.slice(1, feeCards.length - 1),
    //         harvestCards,
    //         multiplierCards,
    //         requiredCards,
    //         ZERO_ADDRESS
    //     )).wait()

    // console.log('withdraw')
    // await (await chief.withdraw(0,0,utils.parseEther('200'))).wait()

    // console.log('deposit again again')
    // await (await chief
    //     .deposit(
    //         0,
    //         0,
    //         utils.parseEther('100'),
    //         feeCards.slice(0, 1),
    //         feeCards.slice(1, feeCards.length - 1),
    //         harvestCards,
    //         multiplierCards,
    //         requiredCards,
    //         ZERO_ADDRESS
    //     )).wait()

    console.log('transactions done')

    await hre.run('verify:verify', {
        address: chief.address,
        constructorArguments: [],
    })

    await hre.run('verify:verify', {
        address: feeReceiver.address,
        constructorArguments: [],
    })

    await hre.run('verify:verify', {
        address: projectHandler.address,
        constructorArguments: [chief.address, deployer.address, PROJECT_FEE, POOL_FEE, REWARD_FEE, feeReceiver.address, feeReceiver.address, feeReceiver.address],
    })

    await hre.run('verify:verify', {
        address: cardhandler.address,
        constructorArguments: [chief.address],
    })

    await hre.run('verify:verify', {
        address: poolCards.address,
        constructorArguments: [tokenUri],
    })

    await hre.run('verify:verify', {
        address: testToken.address,
        constructorArguments: ['NFTVillageToken'],
    })

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })