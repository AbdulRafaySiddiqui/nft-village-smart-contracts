const { utils, constants } = require("ethers");
const { ethers, upgrades } = require("hardhat");
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

const protocolAddress = "";
const realyerAddress = "";

const relayer = {
  protocolFeeRecipient: protocolAddress,
  relayerAddress: realyerAddress,
  relayerFee: 0,
  protocolFee: 500,
  referralFee: 0,
  referralSide: 0,
  referralEnabled: false,
  referralRegistrationEnabled: false,
  atomicMatchHandler: constants.AddressZero,
};

async function main() {
  const [deployer] = await ethers.getSigners();
  const exchangeContract = await ethers.getContractFactory("NFTVillageExchange");
  const exchange = await exchangeContract.deployProxy(exchangeContract, []);
  await exchange.deployed();
  console.log("Exchange: ", exchange.address);

  console.log(await await exchange.registeredRelayers(relayer.relayerAddress));
  await (await exchange.setRelayer(relayer)).wait();
  console.log("registered relayer");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
