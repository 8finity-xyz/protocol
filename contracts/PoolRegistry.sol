// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {IPoolRegistry} from "./IPoolRegistry.sol";

contract PoolRegistry is
    IPoolRegistry,
    UUPSUpgradeable,
    OwnableUpgradeable,
    EIP712Upgradeable
{
    using ECDSA for bytes32;

    address public constant POW = 0x8888FF459Da48e5c9883f893fc8653c8E55F8888;
    IERC20 public constant INFINITY =
        IERC20(0x888852d1c63c7b333efEb1c4C5C79E36ce918888);

    bytes32 private constant CLAIM_TYPEHASH =
        keccak256("Claim(uint256 poolId,address miner,uint256 totalReward)");

    uint256 public lastPoolId;
    uint256 public amountToLock;

    mapping(address => uint256) public lockedInfinity;

    mapping(uint256 => Pool) public poolById;
    mapping(address => uint256) _poolIdByOwner;

    mapping(uint256 => mapping(address => uint256)) _claimedReward;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner) public virtual initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        __EIP712_init("PoolRegistry", "1");

        amountToLock = 100_000 * 1e18; // 100,000 $8 to create pool
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function changeAmountToLock(uint256 amountToLock_) external onlyOwner {
        amountToLock = amountToLock_;
    }

    function createPool(
        uint16 fee,
        string memory name,
        string memory url
    ) external {
        require(
            _poolIdByOwner[msg.sender] == 0,
            PoolAlreadyCreated(_poolIdByOwner[msg.sender])
        );

        INFINITY.transferFrom(msg.sender, address(this), amountToLock);

        uint256 poolId = ++lastPoolId;
        poolById[poolId] = Pool({
            owner: msg.sender,
            lastSubmit: 0,
            totalReward: 0,
            unfinalizedReward: 0,
            finalizedReward: 0,
            fee: fee,
            name: name,
            url: url
        });
        lockedInfinity[msg.sender] = amountToLock;
        _poolIdByOwner[msg.sender] = poolId;

        emit PoolCreated(poolId, msg.sender, fee, name, url);
    }

    function updatePool(
        uint8 fee,
        string memory name,
        string memory url
    ) external {
        (uint256 poolId, Pool storage pool) = _getPool();

        pool.name = name;
        pool.fee = fee;
        pool.url = url;

        emit PoolUpdated(poolId, fee, name, url);
    }

    function closePool() external {
        (uint256 poolId, Pool storage pool) = _getPool();

        // finalize reward last time
        uint256 reward = pool.unfinalizedReward;
        pool.unfinalizedReward = 0;
        pool.finalizedReward += reward;
        pool.lastSubmit = block.timestamp;

        // disable all interactions with pool
        pool.owner = address(0);

        emit PoolClosed(poolId);
    }

    function unlockInfinity() external {
        (, Pool storage pool) = _getPool();

        uint256 lastSubmit = pool.lastSubmit;
        require(
            pool.owner == address(0) && // pool closed
                (block.timestamp - lastSubmit) > 7 days // unlock after 7 days
        );

        uint256 amount = lockedInfinity[msg.sender];
        lockedInfinity[msg.sender] = 0;
        delete _poolIdByOwner[msg.sender];

        INFINITY.transfer(msg.sender, amount);
    }

    function _notifyReward(uint256 poolId, uint256 reward) external {
        require(msg.sender == POW);
        require(poolById[poolId].owner != address(0));

        poolById[poolId].unfinalizedReward += reward;
    }

    function finalizeReward(uint256 submitsCost) external {
        (, Pool storage pool) = _getPool();

        uint256 reward = pool.unfinalizedReward;
        pool.unfinalizedReward = 0;

        // reward = miners reward + pool fee + submits cost
        // 1. we sell submits cost and transfer S to pool owner
        // 2. we transfer fees to pool owner
        // 3. remaining tokens goes to miners reward

        _sellInfinity(submitsCost, msg.sender);

        uint256 minersReward = reward - submitsCost;
        uint256 fee = (minersReward * pool.fee) / 1e4;
        minersReward -= fee;
        INFINITY.transfer(msg.sender, fee);

        pool.finalizedReward += minersReward;
        pool.lastSubmit = block.timestamp;
        pool.totalReward += minersReward;
    }

    function claim(
        uint256 poolId,
        address miner,
        uint256 totalReward,
        bytes calldata signature
    ) external {
        Pool storage pool = poolById[poolId];
        require(
            _hashTypedDataV4(
                keccak256(
                    abi.encode(CLAIM_TYPEHASH, poolId, miner, totalReward)
                )
            ).recover(signature) == pool.owner
        );

        uint256 reward = totalReward - _claimedReward[poolId][miner];
        _claimedReward[poolId][miner] = totalReward;
        pool.finalizedReward -= reward;

        INFINITY.transfer(miner, reward);
        emit RewardClaimed(miner, poolId, reward);
    }

    function getPoolId(address owner) external view returns (uint256 poolId) {
        poolId = _poolIdByOwner[owner];
        require(poolId > 0, PoolNotFound(owner));
    }

    function quiteFinalizeReward(
        uint256 submitsCostNative
    ) external returns (uint256 submitsCost) {}

    function _getPool()
        internal
        view
        returns (uint256 poolId, Pool storage pool)
    {
        poolId = _poolIdByOwner[msg.sender];
        require(poolId != 0, PoolNotFound(msg.sender));
        pool = poolById[poolId];
    }

    function _sellInfinity(uint256 amount, address to) internal {
        // TODO: sell Infinity (if mainnet)
    }
}
