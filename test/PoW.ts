import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { loadFixture, setCode, setStorageAt } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { secp256k1 } from "@noble/curves/secp256k1";
import { PoW } from "../typechain-types";

const pk2hex = (pk: bigint) => ('0'.repeat(64) + pk.toString(16)).slice(-64)

describe("PoW", function () {
    async function deploy() {
        const [owner, submitter, rewardReciever] = await ethers.getSigners()

        const PoW = await ethers.getContractFactory("PoW");
        const pow = (await upgrades.deployProxy(
            PoW,
            [owner.address],
            { unsafeAllow: ["missing-initializer-call"] }
        )) as unknown as PoW;
        await upgrades.upgradeProxy(
            await pow.getAddress(),
            PoW,
            { unsafeAllow: ["missing-initializer-call"], call: { fn: "initialize2" } }
        )

        const token = await ethers.deployContract("Infinity", [owner])
        const infinity = await ethers.getContractAt("Infinity", await pow.INFINITY())
        await setCode(await infinity.getAddress(), await token.getDeployedCode() || '0x')
        await setStorageAt(await infinity.getAddress(), 2, await token.totalSupply())
        await setStorageAt(
            await infinity.getAddress(),
            ethers.solidityPackedKeccak256(
                ["uint256", "uint256"],
                [await pow.getAddress(), 0n]
            ),
            await token.totalSupply()
        )

        await pow.startMining(ethers.parseEther("1"));

        return { infinity, pow, submitter, rewardReciever }
    }

    it("should mine", async function () {
        const { pow, infinity, submitter, rewardReciever } = await loadFixture(deploy)
        const MAGIC_NUMBER = 0x8888888888888888888888888888888888888888n;

        let privateKeyA = await pow.privateKeyA();
        let difficulty = await pow.difficulty();
        let privateKeyB = 1n;

        while (true) {
            privateKeyB++;
            const accountB = new ethers.Wallet(pk2hex(privateKeyB));
            const publicKeyB = secp256k1.ProjectivePoint.fromHex(accountB.signingKey.publicKey.substring(2))

            const privateKeyAB = (privateKeyA + privateKeyB) % secp256k1.CURVE.p;
            const accountAB = new ethers.Wallet(pk2hex(privateKeyAB));

            if ((BigInt(accountAB.address) ^ MAGIC_NUMBER) >= difficulty) {
                continue
            }

            const data = ethers.toUtf8Bytes("test")

            const messageHash = ethers.getBytes(ethers.solidityPackedKeccak256(
                ["address", "bytes"],
                [rewardReciever.address, data]
            ))

            const reward = await pow.reward();
            const tx = pow.connect(submitter).submit(
                rewardReciever,
                { x: publicKeyB.px, y: publicKeyB.py },
                await accountAB.signMessage(messageHash),
                data
            )
            await expect(tx).to.be.not.reverted
            await expect(tx).changeTokenBalance(infinity, rewardReciever, reward)
            break
        }
    })

});