// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {secp256k1, ECCPoint} from "../secp256k1.sol";

contract Secp256k1Test {
    function toPublicKey(
        uint256 privateKey
    ) external pure returns (ECCPoint memory) {
        return secp256k1.toPublicKey(privateKey);
    }

    function ecAdd(
        ECCPoint memory p1,
        ECCPoint memory p2
    ) external pure returns (ECCPoint memory) {
        return secp256k1.ecAdd(p1, p2);
    }

    function toAddress(ECCPoint memory p) external pure returns (address) {
        return secp256k1.toAddress(p);
    }
}
