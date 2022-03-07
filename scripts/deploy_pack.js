const { utils, constants } = require("ethers");
const { ethers } = require("hardhat");
const hre = require("hardhat");

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
const DEAD_ADDRESS = "0x000000000000000000000000000000000000dEaD";

const SAQLAIN = "0x283070d8D9ff69fCC9f84afE7013C1C32Fd5A19F";
const MUZAMMMIL = "0x97e54D0e19C6e457e392727b3F1C556b26C2178B";
const TOKEN_URI = "https://metaflokirush.mypinata.cloud/ipfs/QmRYEZMCfiAoMvQpvovVU56T1vhEqJcyY5HJpqjj22nYD5/1234/{id}";

const RANDOM_MINTING_PRICE = utils.parseEther("0.3");

const COMMON_PRICE = utils.parseEther("0.25");
const RARE_PRICE = utils.parseEther("0.4");
const SUPER_RARE_PRICE = utils.parseEther("0.6");
const EPIC_PRICE = utils.parseEther("1.2");
const LEGENDARY_PRICE = utils.parseEther("4");

const FEE_RECIPIENT = "0x3692da0b95c75b191188202B27e3C945B23F0Fd0";
const PAYMENT_TOKEN = ZERO_ADDRESS;
// Common
const getCommon = () => [
  // { tokenId: 0, chest: 75, sale: 35 },
  // { tokenId: 1, chest: 75, sale: 35 },
  // { tokenId: 2, chest: 75, sale: 35 },
  // { tokenId: 3, chest: 80, sale: 40 },
  // { tokenId: 4, chest: 54, sale: 27 },
];
// Rare
const getRare = () => [
  // { tokenId: 5, chest: 54, sale: 27 },
  // { tokenId: 6, chest: 54, sale: 27 },
  // { tokenId: 7, chest: 53, sale: 29 },
  // { tokenId: 8, chest: 40, sale: 12 },
];
// Super Rare
const getSuperRare = () => [
  // { tokenId: 9, chest: 40, sale: 12 },
  // { tokenId: 10, chest: 45, sale: 11 },
  // { tokenId: 11, chest: 12, sale: 4 },
];
// Epic
const getEpic = () => [
  // { tokenId: 12, chest: 12, sale: 4 },
  // { tokenId: 13, chest: 12, sale: 5 },
];
// Legendary
const getLegendary = () => [{ tokenId: 14, chest: 4, sale: 11 }];
const RARE_SPECIAL_EDITION = { tokenId: 15, amount: 197 };
const TOKENS = [...getCommon(), ...getRare(), ...getSuperRare(), ...getEpic(), ...getLegendary()];

const getArray = (length, callback = (index) => index) => {
  return Array.from(new Array(length), (_, index) => callback(index));
};

const getRarties = () => {
  return [
    { weight: 40, tokenIds: getCommon().map((e) => e.tokenId) },
    { weight: 30, tokenIds: getRare().map((e) => e.tokenId) },
    { weight: 20, tokenIds: getSuperRare().map((e) => e.tokenId) },
    { weight: 8, tokenIds: getEpic().map((e) => e.tokenId) },
    { weight: 2, tokenIds: getLegendary().map((e) => e.tokenId) },
  ];
};

const getPacks = (nft) => {
  const pack = (nft, tokenId, price) => {
    return {
      nft: nft,
      tokenIds: [tokenId],
      nftType: 1,
      paymentToken: PAYMENT_TOKEN,
      price: price,
      enabled: true,
    };
  };

  return [
    ...getCommon().map((e) => pack(nft, e.tokenId, COMMON_PRICE)),
    ...getRare().map((e) => pack(nft, e.tokenId, RARE_PRICE)),
    ...getSuperRare().map((e) => pack(nft, e.tokenId, SUPER_RARE_PRICE)),
    ...getEpic().map((e) => pack(nft, e.tokenId, EPIC_PRICE)),
    ...getLegendary().map((e) => pack(nft, e.tokenId, LEGENDARY_PRICE)),
  ];
};

async function main() {
  const [deployer] = await ethers.getSigners();

  // ------------ NFT PACK SALE
  const nftContract = await ethers.getContractFactory("MetaFlokiRushNFT");
  // const nft = await nftContract.deploy(TOKEN_URI);
  const nft = await nftContract.attach("0x200D429421c53d75f0f9E4f92bC048c40915a9aa");
  console.log(`NFTVillageERC1155: ${nft.address}`);

  const packsaleContract = await ethers.getContractFactory("NFTPackSale");
  // const packsale = await packsaleContract.attach('0xD184B598E90a67BDc3494F1131d48FFb8E0b5A56');
  const oldPacksale = await packsaleContract.attach("0xD184B598E90a67BDc3494F1131d48FFb8E0b5A56");
  //   const packsale = await packsaleContract.deploy(FEE_RECIPIENT);
  const packsale = await packsaleContract.attach("0x4160a8aBEc4C808ff6b0E46862C79717A090e732");
  console.log(`NFTPackSale: ${packsale.address}`);

  //   await sleep(50);

  //   console.log("Adding Packs");
  //   await (await packsale.addPacks(getPacks(nft.address))).wait();

  for (let i = 0; i < TOKENS.length; i++) {
    const element = TOKENS[i];
    console.log("transfering..", element.tokenId);
    await (
      await oldPacksale.withdrawNFT(
        nft.address,
        1,
        oldPacksale.address,
        packsale.address,
        element.tokenId,
        element.sale
      )
    ).wait();
  }

  // // -------- NFT RANDOM SALE
  // const randomSaleContract = await ethers.getContractFactory("NFTRandomSale");
  // const randomSale = await randomSaleContract.attach('0xEc972cCFEb157bD554BE3539Cf60A4F49B0656d4');
  // // const randomSale = await randomSaleContract.deploy(PAYMENT_TOKEN, RANDOM_MINTING_PRICE, nft.address, FEE_RECIPIENT);
  // console.log(`NFTRandomSale: ${randomSale.address}`)

  // console.log('adding rarities')
  // await (await randomSale.addRarities(getRarties())).wait()

  // ------------- NFT CLAIM
  // const giftContract = await ethers.getContractFactory("NFTGiftClaim");
  // // const gift = await giftContract.deploy(nft.address, RARE_SPECIAL_EDITION.tokenId);
  // const gift = await giftContract.attach('0x6DF9bCEB64D7cd91D8c46d8F1715dFeE49E070fD');
  // console.log(`NFTGiftClaim: ${gift.address}`)

  // console.log('Minting nfts')
  // await (await nft.mintBatch(packsale.address, TOKENS.map(e => e.tokenId), TOKENS.map(e => e.sale), [[]])).wait()
  // await (await nft.mintBatch(randomSale.address, TOKENS.map(e => e.tokenId), TOKENS.map(e => e.chest), [[]])).wait()
  // await (await nft.mint(gift.address, RARE_SPECIAL_EDITION.tokenId, 1, [])).wait()

  // console.log('minting nfts to users')
  // await (await nft.mintBatch(SAQLAIN, TOKENS.map(e => e.tokenId), TOKENS.map(e => 1), [[]])).wait()
  // await (await nft.mintBatch(MUZAMMMIL, TOKENS.map(e => e.tokenId), TOKENS.map(e => 1), [[]])).wait()
  // await (await nft.mintBatch(deployer.address, TOKENS.map(e => e.tokenId), TOKENS.map(e => 1), [[]])).wait()

  // console.log('assign signer')
  // await (await gift.grandRewardSignerRole('0x94E3574a4A3dFAcD45903DdF475aE12a87C66f9c'))

  // await (await gift.setClaimEnabled(true)).wait()

  console.log("Transactions DONE");

  await hre.run("verify:verify", {
    address: packsale.address,
    constructorArguments: [FEE_RECIPIENT],
  });
  // await hre.run('verify:verify', {
  //     address: randomSale.address,
  //     constructorArguments: [PAYMENT_TOKEN, RANDOM_MINTING_PRICE, nft.address, FEE_RECIPIENT],
  // })
  // await hre.run('verify:verify', {
  //     address: gift.address,
  //     constructorArguments: [nft.address, RARE_SPECIAL_EDITION.tokenId],
  // })
  // await hre.run('verify:verify', {
  //     address: nft.address,
  //     contract: 'contracts/tokens/MetaFlokiRushNFT.sol:MetaFlokiRushNFT',
  //     constructorArguments: [TOKEN_URI],
  // })
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
