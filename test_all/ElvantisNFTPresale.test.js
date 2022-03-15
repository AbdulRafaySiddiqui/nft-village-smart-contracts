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

        const nftSellContract = await ethers.getContractFactory('ElvantisNFTPresale');
        nftPresale = await nftSellContract.deploy(feeRecipient.address, deployer.address, deployer.address, '0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da', 100);
    })

    it('It should mint nfts', async () => {
        await nft.mint(nftPresale.address, 0, 1)
        await nft.mint(nftPresale.address, 1, 1)
        await nft.mint(nftPresale.address, 2, 1)
        await nft.mint(nftPresale.address, 3, 1)
        await nft.mint(nftPresale.address, 4, 1)
        await nft.mint(nftPresale.address, 5, 1)
    })

    it('it should add packs', async () => {
        await expect(nftPresale.addPack(nft.address, 1, ZERO_ADDRESS, LESS_ETH, true, [
            {
                tokenId: 0,
                weight: 1,
            },
            {
                tokenId: 1,
                weight: 3,
            },
            {
                tokenId: 2,
                weight: 5,
            },
            {
                tokenId: 3,
                weight: 10,
            },
            {
                tokenId: 4,
                weight: 10,
            },
            {
                tokenId: 5,
                weight: 10,
            }
        ])).to.emit(nftPresale, 'PackAdded');
    })

    it('it should queue order', async () => {
        let packSoldEvent = new Promise((resolve, reject) => {
            nftPresale.on('BuyOrderQueued', (requestId, packId, user, event) => {
                event.removeListener();
                requestId = requestId;
                resolve({
                    requestId: requestId,
                    packId: packId,
                    user: user,
                });
            });

            setTimeout(() => {
                reject(new Error('timeout'));
            }, 60000)
        });

        await expect(nftPresale.connect(user).buyPack(0, { value: LESS_ETH }))
            .to.emit(nftPresale, 'BuyOrderQueued');
        const event = await packSoldEvent;
        requestId = event.requestId
    })

    it('it should put order in pending', async () => {
        await expect(nftPresale.rawFulfillRandomness(requestId, '134523463456734574567'))
            .to.emit(nftPresale, 'BuyOrderPending')
        const order = await nftPresale.buyOrders(requestId);
        expect(order.status).to.equal(1);
    })

    it('it should fulfill order', async () => {
        await expect(nftPresale.claimNFT(requestId))
            .to.emit(nftPresale, 'BuyOrderFulfilled')
        const order = await nftPresale.buyOrders(requestId);

        const nftBalance = await nft.balanceOf(user.address, order.tokenId)
        expect(nftBalance).to.deep.eq(1)
    })

})
