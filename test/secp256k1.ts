import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { secp256k1 } from "@noble/curves/secp256k1";


describe("secp256k1", function () {
    function genKeys() {
        const account = ethers.Wallet.createRandom()
        const privateKey = account.signingKey.privateKey
        const address = account.address
        const point = secp256k1.ProjectivePoint.fromPrivateKey(privateKey.substring(2,))

        return {
            privateKey, address, point
        }
    }

    async function deploy() {
        const secp256k1 = await ethers.deployContract("Secp256k1Test")
        return { secp256k1 }
    }

    it("should correct calculate public key from private key", async function () {
        const lib = await loadFixture(deploy)
        const { privateKey, point } = genKeys()

        expect(
            await lib.secp256k1.toPublicKey(privateKey)
        ).to.be.deep.eq([point.x, point.y])
    })

    it("should correct calculate ec point sum", async function () {
        const lib = await loadFixture(deploy)
        const { point: point1, privateKey: privateKey1 } = genKeys()
        const { point: point2, privateKey: privateKey2 } = genKeys()

        const point12 = point1.add(point2)

        expect(
            await lib.secp256k1.ecAdd(point1, point2)
        ).to.be.deep.eq([point12.x, point12.y])

    })

    it("should correct calculate address from public key", async function () {
        const lib = await loadFixture(deploy)
        const { point, address } = genKeys()

        expect(
            await lib.secp256k1.toAddress(point)
        ).to.be.eq(address)
    })
})