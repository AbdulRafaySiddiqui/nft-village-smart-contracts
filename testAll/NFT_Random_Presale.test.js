const { ethers } = require('hardhat')
const { expect, use } = require('chai')
const { solidity } = require('ethereum-waffle')
const { utils } = ethers
const RandomPresale_Abi = require('../abi/RandomPresale_abi.json')

use(solidity)


const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'
const ONE_ETH = utils.parseUnits('1000000', 5)

let deployer
let user;
let nft;
let nftRandomSale;

describe('NFT', () => { 

    it('It should deploy contracts', async () => { 
        [deployer,user] = await ethers.getSigners()

        const nftContract = await ethers.getContractFactory('NFTVillageCards')
        nft = await nftContract.deploy("assadad")

        const nftRandomSale_Contract = await ethers.getContractFactory('NFTRandomPresale');
        nftRandomSale = await nftRandomSale_Contract.deploy(ZERO_ADDRESS,ONE_ETH, nft.address);
    })

    it('It should mint nfts and Add rarity to rarity list', async () => {
        await nft.mint(deployer.address, 0, 1)
        const rarity1 = [0];
        await nft.mint(deployer.address, 1, 1)
        await nft.mint(deployer.address, 2, 1)
        const rarity2 = [1,2]
        await nft.mint(deployer.address, 3, 1)
        await nft.mint(deployer.address, 4, 4)
        const rarity3 = [3,4]

        //Rarity1
        await expect(nftRandomSale.connect(deployer).addRarity(6,rarity1)).to.emit(nftRandomSale,'RarityAdded')
        //Rarity2
        await expect(nftRandomSale.connect(deployer).addRarity(3,rarity2)).to.emit(nftRandomSale,'RarityAdded')
        //Rarity3
        await expect(nftRandomSale.connect(deployer).addRarity(1,rarity3)).to.emit(nftRandomSale,'RarityAdded')
        
        await nft.connect(deployer).setApprovalForAll(nftRandomSale.address, true)
    })

    
    // it('It should buy Pack and check balance', async () => {

        
    //  //   const tx = await expect(nftRandomSale.connect(user).buyPack({value:ONE_ETH})).to.emit(nftRandomSale,'Buy')

    //     tx =await (await nftRandomSale.connect(user).buyPack({value:ONE_ETH})).wait()
       
    //     // checking balance
    //     const iface = new ethers.utils.Interface(RandomPresale_Abi);
    //     const tokenId = iface.parseLog(tx.logs[1]).args['tokenId'].toString()
    //     console.log('tokenId', tokenId)

    //     expect(await nft.balanceOf(user.address, tokenId)).to.eq(1)
        
        
    // })

    it('It Should buy all packs',async () => {

        //buy1
        tx =await (await nftRandomSale.connect(user).buyPack({value:ONE_ETH})).wait()
        // checking balance
        const iface = new ethers.utils.Interface(RandomPresale_Abi);
        const tokenId = iface.parseLog(tx.logs[1]).args['tokenId'].toString()
        console.log('tokenId', tokenId)
   //     expect(await nft.balanceOf(user.address, tokenId)).to.eq(1)

        //buy2

        tx2 =await (await nftRandomSale.connect(user).buyPack({value:ONE_ETH})).wait()
        // checking balance
        const aiface = new ethers.utils.Interface(RandomPresale_Abi);
        const tokenIds = aiface.parseLog(tx2.logs[1]).args['tokenId'].toString()
        console.log('tokenId', tokenIds)
   //     expect(await nft.balanceOf(user.address, tokenIds)).to.eq(1)

        //buy3
        
        tx3 =await (await nftRandomSale.connect(user).buyPack({value:ONE_ETH})).wait()
        // checking balance
        const iface2 = new ethers.utils.Interface(RandomPresale_Abi);
        const tokenId3 = iface2.parseLog(tx3.logs[1]).args['tokenId'].toString()
        console.log('tokenId', tokenId3)
   //     expect(await nft.balanceOf(user.address, tokenId3)).to.eq(1)

        //buy4
        
        tx4 =await (await nftRandomSale.connect(user).buyPack({value:ONE_ETH})).wait()
        // checking balance
        const iface4 = new ethers.utils.Interface(RandomPresale_Abi);
        const tokenId4 = iface4.parseLog(tx4.logs[1]).args['tokenId'].toString()
        console.log('tokenId', tokenId4)
   //     expect(await nft.balanceOf(user.address, tokenId4)).to.eq(1)

        //buy5

        tx5 =await (await nftRandomSale.connect(user).buyPack({value:ONE_ETH})).wait()
        // checking balance
        const iface5 = new ethers.utils.Interface(RandomPresale_Abi);
        const tokenId5 = iface5.parseLog(tx5.logs[1]).args['tokenId'].toString()
        console.log('tokenId', tokenId5)
   //     expect(await nft.balanceOf(user.address, tokenId5)).to.eq(1)
        
        
        //buy6

        tx6 =await (await nftRandomSale.connect(user).buyPack({value:ONE_ETH})).wait()
        // checking balance
        const iface6 = new ethers.utils.Interface(RandomPresale_Abi);
        const tokenId6 = iface6.parseLog(tx6.logs[1]).args['tokenId'].toString()
        console.log('tokenId', tokenId6)
   //     expect(await nft.balanceOf(user.address, tokenId6)).to.eq(1)
    })
})
