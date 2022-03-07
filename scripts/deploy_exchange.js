const { ethers, upgrades } = require("hardhat");
const hre = require("hardhat");

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

const name = 'NFT Village';
const symbol = 'VLG';
const uri = 'https://dc-metadata-api.herokuapp.com/api/{address}';

const protocolAddress = '0x07e056FC48b3dfCfB1377f0f2AE786A636673Ee7'
const realyerAddress = '0x947F55f2323C31cC9cD143a808EB10656eEc1387'

const relayer = {
    protocolFeeRecipient: protocolAddress, // work account
    relayerAddress: realyerAddress, // dechains
    relayerFee: 150,
    protocolFee: 150,
    referralFee: 0,
    referralSide: 0,
    referralEnabled: false,
    referralRegistrationEnabled: false,
    atomicMatchHandler: ZERO_ADDRESS
}

async function main() {
    //Deploy contracts
    const [deployer] = await ethers.getSigners();

    const exchangeContract = await ethers.getContractFactory("NFTVillageExchange")
    // const exchange = await upgrades.deployProxy(exchangeContract, []);
    // await exchange.deployed();
    // const exchange = await exchangeContract.attach('0x1ebd355b22eae4CB024Dea5EC82E79adf6421179')
    const exchange = await exchangeContract.attach('0xe29E577421aF9F70b94B056D2d8aEdF54DE82Acb')
    console.log('Exchange: ', exchange.address)

    // console.log(await (await exchange.registeredRelayers(relayer.relayerAddress)))
    await (await exchange.setRelayer(relayer)).wait()
    console.log('registered relayer')

    //   const nftvillageContract = await ethers.getContractFactory("NFTVillageERC721");
    //   const nftvillage = await nftvillageContract.deploy(name, symbol, uri);
    //   console.log("NFT Village: ", nftvillage.address);

    // await sleep(100)

    // Verify Contracts
    // await hre.run("verify:verify", {
    //     address: exchange.address,
    //     constructorArguments: [],
    // });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })
