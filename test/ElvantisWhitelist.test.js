const { ethers, waffle } = require('hardhat')
const { expect, use, util } = require('chai')
const { solidity } = require('ethereum-waffle')
const { BigNumber, utils, provider } = ethers

use(solidity)

const ZERO = new BigNumber.from('0')
const ONE = new BigNumber.from('1')
const LESS_ETH = utils.parseUnits('0.001')
const ONE_ETH = utils.parseUnits('1')
const MORE_ETH = utils.parseUnits('10000000000000')
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'
const MAX_UINT = '115792089237316195423570985008687907853269984665640564039457584007913129639935'

const MIN_CONTRIBUTION = utils.parseUnits('1');
const MAX_CONTRIBUTION = utils.parseUnits('3');
const MAX_ROUND_LIMIT = utils.parseUnits('4')
const TOKEN_RATE = '10000';

let token, whitelist, deployer, user, signer;

const signContributor = async (whitelist, account, deadline) => {
    const { chainId } = await provider.getNetwork()
    const domain = {
        name: 'ELVANTIS_WHITELIST',
        version: '1',
        chainId,
        verifyingContract: whitelist,
    }
    const types = {
        Contribute: [
            { name: 'user', type: 'address' },
            { name: 'deadline', type: 'uint256' },
        ]
    }
    const message = {
        user: account,
        deadline: deadline,
    }

    const signature = await signer._signTypedData(domain, types, message);
    return utils.splitSignature(signature);
}

describe('Whitelist', () => {
    it('it should deploy contract and grant signer role and add 1 round', async () => {
        [deployer, signer, user, router] = await ethers.getSigners()

        const sampleTokenContract = await ethers.getContractFactory('Elvantis');
        token = await sampleTokenContract.deploy(deployer.address, router.address);

        const whitelistContract = await ethers.getContractFactory('ElvantisWhitelist')
        whitelist = await whitelistContract.deploy(token.address, deployer.address, MIN_CONTRIBUTION, MAX_CONTRIBUTION, TOKEN_RATE)

        await whitelist.grandRewardSignerRole(signer.address);
        const WHITELIST_SIGNER_ROLE = await whitelist.WHITELIST_SIGNER_ROLE();
        expect(await whitelist.hasRole(WHITELIST_SIGNER_ROLE, signer.address)).to.be.eq(true)

        await token.mint(whitelist.address, MORE_ETH)

        await whitelist.addRound(MAX_ROUND_LIMIT)
        await whitelist.moveToNextRound()
    })

    it('it should sign contributor and verify it and contribute', async () => {
        const timestamp = (await provider.getBlock(await provider.getBlockNumber())).timestamp;
        const deadline = timestamp + 60 * 60 * 24;
        const signature = await signContributor(whitelist.address, user.address, deadline)

        await expect(whitelist.connect(user).contribute(deadline, signature.v, signature.r, signature.s, { value: ONE_ETH })).to.reverted;

        await whitelist.setContributionEnabled(true);

        await expect(whitelist.connect(user).contribute(deadline, signature.v, signature.r, signature.s, { value: LESS_ETH }))
            .to.revertedWith("ElvantisWhitelist: Minimun Contribution not met")

        await whitelist.connect(user).contribute(deadline, signature.v, signature.r, signature.s, { value: MIN_CONTRIBUTION })
        await whitelist.connect(user).contribute(deadline, signature.v, signature.r, signature.s, { value: MIN_CONTRIBUTION })
        await whitelist.connect(user).contribute(deadline, signature.v, signature.r, signature.s, { value: MIN_CONTRIBUTION })

        await expect(whitelist.connect(user).contribute(deadline, signature.v, signature.r, signature.s, { value: MIN_CONTRIBUTION }))
            .to.revertedWith("ElvantisWhitelist: Maximum Contribution exceeded")

        const signature2 = await signContributor(whitelist.address, signer.address, deadline)
        await whitelist.connect(signer).contribute(deadline, signature2.v, signature2.r, signature2.s, { value: MIN_CONTRIBUTION })

        const signature3 = await signContributor(whitelist.address, signer.address, deadline)
        await expect(whitelist.connect(signer).contribute(deadline, signature3.v, signature3.r, signature3.s, { value: MAX_CONTRIBUTION }))
            .to.revertedWith("ElvantisWhitelist: Hardcap for current round is filled")

    })

    it("it should not claim tokens", async () => {
        await expect(whitelist.connect(deployer).claim())
            .to.revertedWith("ElvantisWhitelist: Claim disabled")

        await whitelist.setClaimEnabled(true)

        await expect(whitelist.connect(deployer).claim())
            .to.revertedWith("ElvantisWhitelist: Only contributors are allowed to claim")
    })

    it('it should claim tokens', async () => {
        const expectedClaimTokens = ONE_ETH.add(ONE_ETH).add(ONE_ETH).mul(TOKEN_RATE);

        const balanceBefore = await token.balanceOf(user.address)
        await whitelist.connect(user).claim()
        const balance = (await token.balanceOf(user.address)).sub(balanceBefore)

        expect(expectedClaimTokens).to.deep.eq(balance)
    })

    it('it should move the next round', async () => {
        await whitelist.addRound(MAX_ROUND_LIMIT)
        await whitelist.moveToNextRound()
        await expect(whitelist.moveToNextRound())
            .to.be.revertedWith("ElvantisWhitelist: Rounds are finished")

        console.log((await whitelist.totalContributions(1)).toString())
    })
})