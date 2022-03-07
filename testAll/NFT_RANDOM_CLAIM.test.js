const { ethers, waffle } = require("hardhat");
const { expect, use, util } = require("chai");
const { solidity } = require("ethereum-waffle");
const { BigNumber, utils, provider } = ethers;

use(solidity);

const ZERO = new BigNumber.from("0");
const ONE = new BigNumber.from("1");
const LESS_ETH = utils.parseUnits("0.001");
const ONE_ETH = utils.parseUnits("1");
const MORE_ETH = utils.parseUnits("10000000000000");
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const MAX_UINT =
  "115792089237316195423570985008687907853269984665640564039457584007913129639935";

const MIN_CONTRIBUTION = utils.parseUnits("1");
const MAX_CONTRIBUTION = utils.parseUnits("3");
const MAX_ROUND_LIMIT = utils.parseUnits("4");
const TOKEN_RATE = "10000";
const NFTGiftClaim = require("../abi/NFTGiftClaim.json")

let nft, whitelist, deployer, user1,user2,user3,user4, signer;

const signContributor = async (whitelist, account, deadline) => {
  const { chainId } = await provider.getNetwork();
  const domain = {
    name: "NFTVILLAGE_WHITELIST",
    version: "1",
    chainId,
    verifyingContract: whitelist,
  };
  const types = {
    Contribute: [
      { name: "user", type: "address" },
      { name: "deadline", type: "uint256" },
    ],
  };
  const message = {
    user: account,
    deadline: deadline,
  };

  const signature = await signer._signTypedData(domain, types, message);
  return utils.splitSignature(signature);
};

describe("Whitelist", () => {
  it("it should deploy contract< mint and grant signer role", async () => {
    [deployer, signer, user1,user2,user3,user4,user5] = await ethers.getSigners();

    const nftContract = await ethers.getContractFactory("NFTVillageERC1155");
    nft = await nftContract.deploy("ABC","AB","assadad");

    console.log("NFT", nft.address);
    console.log(".................................................");

    console.log("..................................................");
    console.log("Minting and Approval.....");

    await nft.mint(deployer.address, 0, 1);
    await nft.mint(deployer.address, 1, 1);
    await nft.mint(deployer.address, 2, 2);
    await nft.mint(deployer.address, 3, 1);

    const whitelistContract = await ethers.getContractFactory("NFTGiftClaim");
    whitelist = await whitelistContract.deploy(nft.address,deployer.address);

    
    console.log("NFT", whitelist.address);
    console.log(".................................................");

    await (
      await nft.connect(deployer).setApprovalForAll(whitelist.address, true)
    ).wait();

 
    await whitelist.grandRewardSignerRole(signer.address);
    await whitelist.setClaimEnabled(true);

    
    console.log("..................................................");
    console.log("Adding tokenIds.....");
    const tokenIds = [0,1,2,3]
    await (await whitelist.connect(deployer).addTokenIds(tokenIds)).wait();

    const WHITELIST_SIGNER_ROLE = await whitelist.WHITELIST_SIGNER_ROLE();
    expect(
      await whitelist.hasRole(WHITELIST_SIGNER_ROLE, signer.address)
    ).to.be.eq(true);
  });


  it("it should sign user1 and verify it and transfer nft", async () => {
    const timestamp = (await provider.getBlock(await provider.getBlockNumber()))
      .timestamp;
    const deadline = timestamp + 60 * 60 * 24;
    const signature = await signContributor(
      whitelist.address,
      user1.address,
      deadline
    );
    
        //buy1
        tx =await (await whitelist.connect(user1)
        .claim(deadline, signature.v, signature.r, signature.s)).wait()
        // checking balance
        const iface = new ethers.utils.Interface(NFTGiftClaim);
        const tokenId = iface.parseLog(tx.logs[1]).args['tokenId'].toString()
        console.log('tokenId', tokenId)    

  });


  it("it should sign user2 and verify it and transfer nft", async () => {
    const timestamp = (await provider.getBlock(await provider.getBlockNumber()))
      .timestamp;
    const deadline = timestamp + 60 * 60 * 24;
    const signature = await signContributor(
      whitelist.address,
      user2.address,
      deadline
    );
    
        //buy2
        tx =await (await whitelist.connect(user2)
        .claim(deadline, signature.v, signature.r, signature.s)).wait()
        // checking balance
        const iface = new ethers.utils.Interface(NFTGiftClaim);
        const tokenId = iface.parseLog(tx.logs[1]).args['tokenId'].toString()
        console.log('tokenId', tokenId)    

  });

  it("it should sign user3 and verify it and transfer nft", async () => {
    const timestamp = (await provider.getBlock(await provider.getBlockNumber()))
      .timestamp;
    const deadline = timestamp + 60 * 60 * 24;
    const signature = await signContributor(
      whitelist.address,
      user3.address,
      deadline
    );
    
        //buy3
        tx =await (await whitelist.connect(user3)
        .claim(deadline, signature.v, signature.r, signature.s)).wait()
        // checking balance
        const iface = new ethers.utils.Interface(NFTGiftClaim);
        const tokenId = iface.parseLog(tx.logs[1]).args['tokenId'].toString()
        console.log('tokenId', tokenId)    

  });


  it("it should sign user4 and verify it and transfer nft", async () => {
    const timestamp = (await provider.getBlock(await provider.getBlockNumber()))
      .timestamp;
    const deadline = timestamp + 60 * 60 * 24;
    const signature = await signContributor(
      whitelist.address,
      user4.address,
      deadline
    );

    
    
        //buy3
        tx =await (await whitelist.connect(user4)
        .claim(deadline, signature.v, signature.r, signature.s)).wait()
        // checking balance
        const iface = new ethers.utils.Interface(NFTGiftClaim);
        const tokenId = iface.parseLog(tx.logs[1]).args['tokenId'].toString()
        console.log('tokenId', tokenId)    

  });


  
  it("it should sign user5 and verify it and transfer nft", async () => {
    const timestamp = (await provider.getBlock(await provider.getBlockNumber()))
      .timestamp;
    const deadline = timestamp + 60 * 60 * 24;
    const signature = await signContributor(
      whitelist.address,
      user5.address,
      deadline
    );

    
    
        //buy3
        tx =await (await whitelist.connect(user5)
        .claim(deadline, signature.v, signature.r, signature.s)).wait()
        // checking balance
        const iface = new ethers.utils.Interface(NFTGiftClaim);
        const tokenId = iface.parseLog(tx.logs[1]).args['tokenId'].toString()
        console.log('tokenId', tokenId)    

  });



//   it("it should not claim tokens", async () => {
//     await expect(whitelist.connect(deployer).claim()).to.revertedWith(
//       "ElvantisWhitelist: Claim disabled"
//     );

//     await whitelist.setClaimEnabled(true);

//     await expect(whitelist.connect(deployer).claim()).to.revertedWith(
//       "ElvantisWhitelist: Only contributors are allowed to claim"
//     );
//   });

});
