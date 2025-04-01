# Infinity (pow memecoin token)

#### Deployments (deployed on Sonic Mainnet and Sonic Blaze Testnet)
| Contract| Address |
|--|--|
| Infinity.sol | 0x888852d1c63c7b333efEb1c4C5C79E36ce918888 |
| PoW.sol | 0x8888FF459Da48e5c9883f893fc8653c8E55F8888 |

#### How to mine

1. You need to get problem parts
- `privateKeyA` - derived from previous solution
-  `difficulty` - controls submissions speed

You can get current values with contract read or listen event with new values
```solidity
    function currentProblem()
        external
        view
        returns (uint256 nonce, uint256 privateKeyA, uint160 difficulty);

event NewProblem(uint256 nonce, uint256 privateKeyA, uint160 difficulty);
```
💡 you can use nonce for validate, that you don't miss any problem. Nonce increments by 1 on every new problem by.

2. Search `privateKeyB` that fits equation `uint160(addressAB ^ MAGIC_NUMBER) < difficulty`, where:
- `MAGIC_NUMBER` - `0x8888888888888888888888888888888888888888`
- `addressAB` - evm address from `publicKeyAB`
- `publicKeyAB` - public key, calculated with private key `privateKeyAB`
- `privateKeyAB` - private key, sum of `privateKeyA`, `privateKeyB`*
- `privateKeyB` - random private key (uint256 number)
 *you should use modulo of sum `(privateKeyA  +  privateKeyB) %  0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141`

3. Sign message by `privateKeyAB`. Message should consist of reward recipient and data (any set of bytes, can be empty). Message should be signed using [EIP-191](https://eips.ethereum.org/EIPS/eip-191)

<details>
<summary>How to construct message</summary>
ethers.js
```javascript
ethers.solidityPackedKeccak256(
    ["address", "bytes"],
    [recipient, data]
)
```

web3.py
```
w3.solidity_keccak(
    ["address", "bytes"],
    [recipient, data]
)
```

solidity
```solidity
keccak256(abi.encodePacked(recipient, data))
```

4. Run transaction with call `PoW.submit`
```solidity
PoW.submit(
    recipient, // used in message in #3
    publicKeyB,
    signatureAB, // calculated in #3
    data, // used in message in #3
);
```

:warning: