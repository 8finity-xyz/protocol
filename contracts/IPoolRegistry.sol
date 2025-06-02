// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IPoolRegistry {
    error PoolNotFound(address owner);
    error PoolAlreadyCreated(uint256 poolId);
    error OnlyPoolOwner();

    event PoolCreated(
        uint256 indexed poolId,
        address indexed owner,
        uint16 fee,
        string name,
        string url
    );
    event PoolUpdated(
        uint256 indexed poolId,
        uint16 fee,
        string name,
        string url
    );
    event PoolClosed(uint256 indexed poolId);

    event RewardClaimed(address miner, uint256 poolId, uint256 amount);

    struct Pool {
        address owner;
        uint256 lastSubmit;
        uint256 unfinalizedReward;
        uint256 finalizedReward;
        uint256 totalReward;
        uint16 fee;
        string name;
        string url;
    }

    function _notifyReward(uint256 poolId, uint256 reward) external;

    function getPoolId(address owner) external view returns (uint256);
}
