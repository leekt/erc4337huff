# ERC4337 Huff

**Huff-golfing for cheap account abstraction**

This repo contains a Huff-rewrite of the [ERC-4337 EntryPoint contract](https://github.com/eth-infinitism/account-abstraction/blob/develop/contracts/core/EntryPoint.sol). The EntryPoint contract is critical infra for ERC-4337 that routes UserOperations (psuedo-transactions) to the correct account contract, including account deployment, validation and execution.

> **Note**
>
> These contracts are **unaudited** and are not recommended for use in production.
>
> The main usage of these contracts is to find out how much gas can be saved by using a Huff EntryPoint.

## Gas calculations

|                | 1 UO    | 2 UO    | 10 UO |
| -------------- | ------- | ------- | ----- |
| HuffEntryPoint | 95,359  | 104,697 | ...   |
| EntryPoint     | 275,991 | 332,073 | ...   |
| -------------- | ------  | -----   | ----- |
| Difference     | 180,632 | 227,376 | ...   |

## Todo

- [ ] Fix bugs
- [ ] Gas estimations

## Acknowledgements

- [ERC4337's EntryPoint](https://github.com/eth-infinitism/account-abstraction/blob/develop/contracts/core/EntryPoint.sol)
- [MinimalAccount](https://github.com/kopy-kat/MinimalAccount)
- [Huffmate](https://github.com/huff-language/huffmate)
- [Huff](https://huff.sh)

## Disclaimer

_These smart contracts are being provided as is. No guarantee, representation or warranty is being made, express or implied, as to the safety or correctness of the user interface or the smart contracts. They have not been audited and as such there can be no assurance they will work as intended, and users may experience delays, failures, errors, omissions, loss of transmitted information or loss of funds. The creators are not liable for any of the foregoing. Users should proceed with caution and use at their own risk._
