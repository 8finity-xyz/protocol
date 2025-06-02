import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { loadFixture, setBalance, setCode, setStorageAt, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { PoolRegistry, PoW } from "../typechain-types";


describe("PoolRegistry", function () {
    async function deploy() {
        const [owner, poolOwner, miner] = await ethers.getSigners()

        const poolRegistry = (await upgrades.deployProxy(
            await ethers.getContractFactory("PoolRegistry"),
            [owner.address],
        )) as PoolRegistry;

        const token = await ethers.deployContract("Infinity", [owner])
        const infinity = await ethers.getContractAt("Infinity", await poolRegistry.INFINITY())
        await setCode(await infinity.getAddress(), await token.getDeployedCode() || '0x')
        await setStorageAt(await infinity.getAddress(), 2, await token.totalSupply())
        await setStorageAt(
            await infinity.getAddress(),
            ethers.solidityPackedKeccak256(
                ["uint256", "uint256"],
                [await owner.getAddress(), 0n]
            ),
            await token.totalSupply()
        )

        const POW = await ethers.getImpersonatedSigner(await poolRegistry.POW());
        await setBalance(POW.address, ethers.parseEther("10000"));

        return { infinity, owner, poolOwner, miner, poolRegistry, POW }
    }

    specify("createPool -> updatePool -> closePool -> unlockInfinity", async function () {
        const { infinity, owner, poolOwner, poolRegistry } = await loadFixture(deploy)

        await infinity.connect(owner).transfer(poolOwner, await poolRegistry.amountToLock());
        await infinity.connect(poolOwner).approve(poolRegistry, ethers.MaxUint256);

        const createTx = await poolRegistry.connect(poolOwner).createPool(
            50,
            "Test Pool",
            "127.0.0.1:1234"
        )
        await expect(createTx).to
            .emit(poolRegistry, "PoolCreated")
            .withArgs(1, poolOwner.address, 50, "Test Pool", "127.0.0.1:1234")
        await expect(createTx).changeTokenBalance(infinity, poolOwner, -(await poolRegistry.amountToLock()));
        await expect(createTx).changeTokenBalance(infinity, poolRegistry, await poolRegistry.amountToLock());
        expect(await poolRegistry.lockedInfinity(poolOwner)).to.be.eq(await poolRegistry.amountToLock());
        expect(await poolRegistry.getPoolId(poolOwner)).to.be.eq(1);
        await expect(
            poolRegistry.connect(poolOwner).createPool(0, "", "")
        ).to.be.revertedWithCustomError(poolRegistry, "PoolAlreadyCreated");

        let pool = await poolRegistry.poolById(1);
        expect(pool.owner).to.be.eq(poolOwner.address);
        expect(pool.fee).to.be.eq(50);
        expect(pool.name).to.be.eq("Test Pool");
        expect(pool.url).to.be.eq("127.0.0.1:1234");

        const updateTx = await poolRegistry.connect(poolOwner).updatePool(
            51,
            "Test Pool2",
            "127.0.0.1:4321"
        )
        await expect(updateTx).to
            .emit(poolRegistry, "PoolUpdated")
            .withArgs(1, 51, "Test Pool2", "127.0.0.1:4321")

        const tx = await poolRegistry.connect(poolOwner).closePool()
        pool = await poolRegistry.poolById(1);
        expect(pool.owner).to.be.eq(ethers.ZeroAddress);
        expect(pool.lastSubmit).to.be.eq((await ethers.provider.getBlock(tx.blockNumber!))?.timestamp);

        await time.increase(7 * 24 * 60 * 60 + 1);
        await expect(poolRegistry.connect(poolOwner).unlockInfinity()).to.be.changeTokenBalance(
            infinity, poolOwner, await poolRegistry.amountToLock()
        )
    })

    specify("_notifyReward -> finalizeReward -> claim", async function () {
        const { infinity, owner, poolOwner, poolRegistry, POW, miner } = await loadFixture(deploy)

        // setup
        const fee = 5000; // 50%
        await infinity.connect(owner).transfer(poolOwner, await poolRegistry.amountToLock());
        await infinity.connect(poolOwner).approve(poolRegistry, await poolRegistry.amountToLock());
        await poolRegistry.connect(poolOwner).createPool(fee, "", "")
        const poolId = await poolRegistry.getPoolId(poolOwner);

        let pool = await poolRegistry.poolById(poolId);
        expect(pool.unfinalizedReward).to.be.eq(0);
        expect(pool.finalizedReward).to.be.eq(0);
        expect(pool.totalReward).to.be.eq(0);

        // _notifyReward
        const reward = 100;
        await infinity.connect(owner).transfer(poolRegistry, reward);
        await poolRegistry.connect(POW)._notifyReward(poolId, reward);

        pool = await poolRegistry.poolById(poolId);
        expect(pool.unfinalizedReward).to.be.eq(reward);
        expect(pool.finalizedReward).to.be.eq(0);
        expect(pool.totalReward).to.be.eq(0);

        // finalizeReward
        const submitsCost = reward / 10;
        const poolFee = (reward - submitsCost) * fee / 1e4;
        const minersReward = reward - submitsCost - poolFee;

        const finalizeRewardTx = poolRegistry.connect(poolOwner).finalizeReward(submitsCost);
        await expect(finalizeRewardTx).to.be.changeEtherBalance(poolOwner, 0)
        await expect(finalizeRewardTx).to.be.changeTokenBalance(infinity, poolOwner, poolFee)

        pool = await poolRegistry.poolById(poolId);
        expect(pool.unfinalizedReward).to.be.eq(0);
        expect(pool.finalizedReward).to.be.eq(minersReward);
        expect(pool.totalReward).to.be.eq(minersReward);

        // claim
        const amountToClaim = minersReward - 10;
        const domain = await poolRegistry.eip712Domain();
        const types = {
            Claim: [
                { name: 'poolId', type: 'uint256' },
                { name: 'miner', type: 'address' },
                { name: 'totalReward', type: 'uint256' },
            ]
        };
        const claimSig = await poolOwner.signTypedData(
            { name: domain.name, version: domain.version, chainId: domain.chainId, verifyingContract: domain.verifyingContract },
            types,
            { poolId, miner: miner.address, totalReward: amountToClaim }
        )

        const claimTx = poolRegistry.connect(miner).claim(poolId, miner, amountToClaim, claimSig);
        await expect(claimTx).to.be.changeTokenBalance(infinity, miner, amountToClaim);

        pool = await poolRegistry.poolById(poolId);
        expect(pool.unfinalizedReward).to.be.eq(0);
        expect(pool.finalizedReward).to.be.eq(minersReward - amountToClaim);
        expect(pool.totalReward).to.be.eq(minersReward);
    })
});