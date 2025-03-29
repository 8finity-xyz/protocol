// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IPoW {
    event Submission(address indexed addressAB, bytes data);
    event NewProblem(uint256 privateKeyA, uint160 difficulty);
    event RewardReduced(uint256 newReward);

    error BadSolution(address addressAB, address target);
    error BadSignature();
}
