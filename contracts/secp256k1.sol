// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EllipticCurve} from "elliptic-curve-solidity/contracts/EllipticCurve.sol";

struct ECCPoint {
    uint256 x;
    uint256 y;
}
using {secp256k1.ecAdd, secp256k1.toAddress} for ECCPoint global;

library secp256k1 {
    uint256 constant GX =
        0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;
    uint256 constant GY =
        0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;
    uint256 constant AA = 0;
    uint256 constant BB = 7;
    uint256 constant PP =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;

    function toPublicKey(
        uint256 privateKey
    ) internal pure returns (ECCPoint memory p) {
        (p.x, p.y) = EllipticCurve.ecMul(privateKey, GX, GY, AA, PP);
    }

    function ecAdd(
        ECCPoint memory p1,
        ECCPoint memory p2
    ) internal pure returns (ECCPoint memory p) {
        (p.x, p.y) = EllipticCurve.ecAdd(p1.x, p1.y, p2.x, p2.y, AA, PP);
    }

    function toAddress(ECCPoint memory p) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(p.x, p.y)))));
    }
}
