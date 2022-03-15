const { ethers, waffle } = require('hardhat')
const { expect, use } = require('chai')
const { solidity } = require('ethereum-waffle')
const { BigNumber, utils, provider } = ethers

use(solidity)

const ZERO = new BigNumber.from('0')
const ONE = new BigNumber.from('1')
const ONE_ETH = utils.parseUnits('1000000', 5)
const LESS_ETH = utils.parseUnits('1', 5)
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'
const DEAD_ADDRESS = '0x000000000000000000000000000000000000dEaD'
const MAX_UINT = '115792089237316195423570985008687907853269984665640564039457584007913129639935'

let weth
let token
let factory
let router
let buyPath
let sellPath
let deployer
let feeTo
let nftPresale;
let nft;
let busd;
let feeRecipient, user, requestId;

describe('NFT', () => {
    it('It should deploy exchange and token', async () => {
        [deployer, feeTo, owner, user, feeRecipient] = await ethers.getSigners()

        const nftContract = await ethers.getContractFactory('ElvantisPoolCards')
        nft = await nftContract.deploy()

        const tokenContract = await ethers.getContractFactory("Elvantis");
        token = await tokenContract.deploy(deployer.address, deployer.address);

        const nftSellContract = await ethers.getContractFactory('ElvantisLandPresale');
        nftPresale = await nftSellContract.deploy(feeRecipient.address);

        await token.mint(user.address, ONE_ETH)
    })

    it('It should mint nfts', async () => {
        await nft.mint(nftPresale.address, 0, 2)
        await nft.mint(nftPresale.address, 1, 2)
        await nft.mint(nftPresale.address, 2, 2)
        await nft.mint(nftPresale.address, 3, 2)
        await nft.mint(nftPresale.address, 4, 2)
        await nft.mint(nftPresale.address, 5, 2)
    })

    it('it should add packs with eth price', async () => {
        await expect(nftPresale.addPack(nft.address, [0, 1, 2, 3, 4], 1, ZERO_ADDRESS, LESS_ETH, true)).to.emit(nftPresale, 'PackAdded');
    })

    it('it should buy pack with eth price', async () => {
        await expect(nftPresale.connect(user).buyPack(0, { value: LESS_ETH }))
            .to.emit(nftPresale, 'PackSold');
    })

    it('it should add packs with token price', async () => {
        await expect(nftPresale.addPack(nft.address, [0, 1, 2, 3, 4], 1, token.address, LESS_ETH, true)).to.emit(nftPresale, 'PackAdded');
    })

    it('it should buy pack with token price', async () => {
        await token.connect(user).approve(nftPresale.address, MAX_UINT)
        await expect(nftPresale.connect(user).buyPack(1)).to.emit(nftPresale, 'PackSold');
    })
})
