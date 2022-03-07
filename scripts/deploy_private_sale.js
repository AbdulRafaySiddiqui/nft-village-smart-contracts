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
const META_FLOKI = '0x2f800cBdDA851b5df3A1C9E629538E49BB9547FF';

async function main() {
    //Deploy contracts
    const [deployer] = await ethers.getSigners()
    user = deployer.address;

    const privateSaleContract = await ethers.getContractFactory("NFTVillagePrivateSaleClaim");
    const privateSale = await privateSaleContract.deploy(META_FLOKI);
    console.log(`NFTVillageChief: ${privateSale.address}`)

    await (await (privateSale.grandRewardSignerRole('0x94E3574a4A3dFAcD45903DdF475aE12a87C66f9c'))).wait()

    await sleep(100)

    await hre.run('verify:verify', {
        address: '0xb7B0e37e3f9F8CaEB3f458aCeEDD1F80EE38bd21',
        constructorArguments: [META_FLOKI],
    })

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })