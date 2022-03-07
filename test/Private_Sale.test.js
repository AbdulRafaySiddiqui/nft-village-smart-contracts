const { ethers, waffle } = require("hardhat");
const { expect, use, util } = require("chai");
const { solidity } = require("ethereum-waffle");
const { BigNumber, utils, provider } = ethers;

use(solidity);

const TOKEN_AMOUNT = utils.parseEther("100000000");
const AMOUNT_TRANSFER = utils.parseEther("1000");

let token, privateSale, deployer, user1, signer;

const signContributor = async (privateSale, account, amount, deadline) => {
  const { chainId } = await provider.getNetwork();
  const domain = {
    name: "NFTVILLAGE_PRIVATESALE",
    version: "1",
    chainId,
    verifyingContract: privateSale,
  };
  const types = {
    Claim: [
      { name: "user", type: "address" },
      { name: "amount", type: "uint256" },
      { name: "deadline", type: "uint256" },
    ],
  };
  const message = {
    user: account,
    amount: amount,
    deadline: deadline,
  };

  const signature = await signer._signTypedData(domain, types, message);
  return utils.splitSignature(signature);
};

describe("privateSale", () => {
  it("it should deploy contract mint and grant signer role", async () => {
    [deployer, signer, user1] = await ethers.getSigners();

    const erc20Contract = await ethers.getContractFactory("TestToken");
    token = await erc20Contract.deploy("TEST");

    console.log("token", token.address);
    console.log(".................................................");

    console.log("..................................................");
    console.log("Minting.....");

    const privateSaleContract = await ethers.getContractFactory("NFTVillagePrivateSaleClaim");
    privateSale = await privateSaleContract.deploy(token.address);

    console.log("PrivateSale", privateSale.address);
    console.log(".................................................");

    await (await token.connect(deployer).mint(privateSale.address, TOKEN_AMOUNT)).wait();

    await privateSale.connect(deployer).grandRewardSignerRole(signer.address);
    await privateSale.connect(deployer).setClaimEnabled(true);

    const CLAIM_SIGNER_ROLE = await privateSale.CLAIM_SIGNER_ROLE();
    expect(await privateSale.hasRole(CLAIM_SIGNER_ROLE, signer.address)).to.be.eq(true);
  });

  it("it should sign user1 and verify it and transfer token", async () => {
    const timestamp = (await provider.getBlock(await provider.getBlockNumber())).timestamp;
    const deadline = timestamp + 60 * 60 * 24;
    const signature = await signContributor(privateSale.address, user1.address, AMOUNT_TRANSFER, deadline);

    //buy1
    await expect(
      privateSale.connect(user1).claim(deadline, AMOUNT_TRANSFER, signature.v, signature.r, signature.s)
    ).to.emit(privateSale, "Claimed");

    const balance = await token.balanceOf(user1.address);
    console.log(balance);
    expect(balance).to.gt(0);
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
