# FLRWrap

> A mint/burn bridge from EVM compatible chains to the Flare Network.

![Github Actions](https://github.com/flrfinance/flr-redeem/workflows/test/badge.svg)

### Getting Started
 * Installation 
```bash
yarn install 
```

 * Testing
```bash
yarn test
# to run hardhat tests
yarn test:hardhat
```

### Dev Notes
Whenever you install new libraries using Foundry, make sure to update your `remappings.txt` file by running `forge remappings > remappings.txt`. This is required because we use `hardhat-preprocessor` and the `remappings.txt` file to allow Hardhat to resolve libraries you install with Foundry.
