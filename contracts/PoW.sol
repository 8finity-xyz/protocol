// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IPoW} from "./IPoW.sol";
import {secp256k1, ECCPoint} from "./secp256k1.sol";

contract PoW is IPoW, UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable {
    using MessageHashUtils for bytes32;
    using ECDSA for bytes32;
    using {secp256k1.toPublicKey} for uint256;

    address constant MAGIC_NUMBER = 0x8888888888888888888888888888888888888888;

    IERC20 public constant INFINITY =
        IERC20(0x888852d1c63c7b333efEb1c4C5C79E36ce918888);

    // all constants hardcoded, because we can't set it after mining starts
    uint256 constant REWARD_REDUCE_PERIOD = 672500;
    uint256 constant REWARD_REDUCE_COUNT = 50;
    uint256 constant REWARD_REDUCE_DENOM = 1147202690439877120; // int(3**(1/8) * 1e18)
    uint256 constant MAX_DIFFICULTY_INCRESE = 8;
    uint256 constant SPEED_TARGET_TIME = 200;
    uint256 constant SPEED_PERIOD = 100;
    uint256 constant PARALLEL_SUBMITS_COUNT = 100;

    // mining info
    uint256 public numSubmissions;
    uint256 public reward;

    // problem info
    uint256 public privateKeyA;
    uint160 public difficulty;

    mapping(uint256 => uint256) _submissionBlocks;

    uint256 _nextPrivateKeyA;
    uint256 public problemNonce;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner) public virtual initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
    }

    function initialize2() external reinitializer(2) {
        __Pausable_init();
        _pause();
    }

    function startMining(uint256 startReward) external onlyOwner {
        _requirePaused();
        _unpause();

        reward = startReward;
        privateKeyA = block.timestamp;
        difficulty = uint160(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function submit(
        address recipient,
        ECCPoint memory publicKeyB,
        bytes memory signatureAB,
        bytes calldata data
    ) external whenNotPaused {
        // Process submition
        address addressAB = publicKeyB
            .ecAdd(privateKeyA.toPublicKey())
            .toAddress();

        // checking, that solution correct
        if ((uint160(addressAB) ^ uint160(MAGIC_NUMBER)) > difficulty) {
            revert BadSolution(
                addressAB,
                address(difficulty ^ uint160(MAGIC_NUMBER))
            );
        }
        emit Submission(msg.sender, addressAB, reward, data);

        // checking, that solver really found privateKeyB
        require(
            addressAB ==
                keccak256(abi.encodePacked(recipient, data))
                    .toEthSignedMessageHash()
                    .recover(signatureAB),
            BadSignature()
        );

        INFINITY.transfer(recipient, reward);
        _nextPrivateKeyA = uint256(
            keccak256(
                abi.encodePacked(_nextPrivateKeyA, publicKeyB.x, publicKeyB.y)
            )
        );

        if ((numSubmissions + 1) % PARALLEL_SUBMITS_COUNT == 0) {
            _ajustDifficulty();
            _reduceReward();

            privateKeyA = _nextPrivateKeyA;
            emit NewProblem(problemNonce++, privateKeyA, difficulty);
        }

        numSubmissions += 1;
    }

    function currentProblem()
        external
        view
        returns (uint256, uint256, uint160)
    {
        return (problemNonce, privateKeyA, difficulty);
    }

    function _ajustDifficulty() internal {
        _submissionBlocks[numSubmissions] = block.number;
        if (numSubmissions < SPEED_PERIOD) return;

        uint160 realTime = uint160(
            block.number - _submissionBlocks[numSubmissions - SPEED_PERIOD]
        );
        // We store info only for last transactions
        delete _submissionBlocks[numSubmissions - SPEED_PERIOD];

        uint256 ajustedDifficulty = Math.max(
            (uint256(difficulty) * realTime) / SPEED_TARGET_TIME,
            difficulty / MAX_DIFFICULTY_INCRESE
        );

        if (ajustedDifficulty > type(uint160).max) {
            difficulty = type(uint160).max;
        } else {
            difficulty = uint160(ajustedDifficulty);
        }
    }

    function _reduceReward() internal {
        if (numSubmissions == 0 || numSubmissions % REWARD_REDUCE_PERIOD != 0)
            return;

        uint256 reduceCounts = numSubmissions / REWARD_REDUCE_PERIOD;
        if (reduceCounts > REWARD_REDUCE_COUNT) return;

        reward = (reward * 1e18) / REWARD_REDUCE_DENOM;
        emit RewardReduced(reward);
    }
}
