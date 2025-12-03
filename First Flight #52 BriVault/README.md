# Tournament Vault – Betting

- Starts: November 06, 2025 Noon UTC
- Ends: November 13, 2025 Noon UTC

- nSLOC: 193

[//]: # (contest-details-open)

## About the Project

This smart contract implements a tournament betting vault using the ERC4626 tokenized vault standard. It allows users to deposit an ERC20 asset to bet on a team, and at the end of the tournament, winners share the pool based on the value of their deposits.

Overview
Participants can deposit tokens into the vault before the tournament begins, selecting a team to bet on. After the tournament ends and the winning team is set by the contract owner, users who bet on the correct team can withdraw their share of the total pooled assets.

The vault is fully ERC4626-compliant, enabling integrations with DeFi protocols and front-end tools that understand tokenized vaults.

## Actors
```
Actors:
owner : Only the owner can set the winner after the event ends. 
Users : Users have to send in asset to the contract (deposit + participation fee).
        users should not be able to deposit once the event starts.
        Users should only join events only after they have made deposit.
```

[//]: # (contest-details-close)

[//]: # (scope-open)

## Scope (contracts)

```
├── src
│   ├── briTechToken.sol
│   └── briVault.sol
```

## Compatibilities
Compatibilities:
  Blockchains:
      - Ethereum/Any EVM
  Tokens:
      - ERC20

[//]: # (scope-close)

[//]: # (getting-started-open)

## Setup

### Build:

```bash
git clone https://github.com/CodeHawks-Contests/2025-11-brivault.git

forge install OpenZeppelin/openzeppelin-contracts

forge install vectorized/solady

forge build
```

### Tests:

```bash
Forge test
```

[//]: # (getting-started-close)

[//]: # (known-issues-open)

## Known Issues

No known Issues

## Vulnerabilities

[H-1 Deposit inconsistency in BriVault::deposit allows depositor to receive shares for self while staking for another](https://codehawks.cyfrin.io/c/2025-11-brivault/s/171) \
[H-2 BriVault::joinEvent allows duplicate joins inflating participant counters](https://codehawks.cyfrin.io/c/2025-11-brivault/s/173) 

[M-1 BriVault::setWinner can run out of gas for large number of participants (Gas DoS)](https://codehawks.cyfrin.io/c/2025-11-brivault/s/214) 

[L-1 BriVault::withdraw can revert due to division by zero when total participant shares are zero](https://codehawks.cyfrin.io/c/2025-11-brivault/s/212) 
