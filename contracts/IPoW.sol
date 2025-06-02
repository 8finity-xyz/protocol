// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IPoW {
    event Submission(
        address indexed miner,
        address indexed addressAB,
        uint256 reward,
        bytes data
    );
    event NewProblem(uint256 nonce, uint256 privateKeyA, uint160 difficulty);
    event RewardReduced(uint256 newReward);

    error BadSolution(address addressAB, address target);
    error BadSignature();
    error AlreadySubmitted(address addressAB);
    error PoolsDisabled();

    function currentProblem()
        external
        view
        returns (uint256 nonce, uint256 privateKeyA, uint160 difficulty);
}
