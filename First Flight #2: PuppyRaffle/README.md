# First Flight #2: Puppy Raffle

- [First Flight #2: Puppy Raffle](#first-flight-2-puppy-raffle)
- [Contest Details](#contest-details)
    - [Prize Pool](#prize-pool)
  - [Stats](#stats)
- [Puppy Raffle](#puppy-raffle)
  - [Roles](#roles)
- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Quickstart](#quickstart)
    - [Optional Gitpod](#optional-gitpod)
- [Usage](#usage)
  - [Testing](#testing)
    - [Test Coverage](#test-coverage)
- [Audit Scope Details](#audit-scope-details)
  - [Compatibilities](#compatibilities)
- [Known Issues](#known-issues)
  - [Vulnerabilites](#vulnerabilites)

# Contest Details

### Prize Pool

- High - 100xp
- Medium - 20xp
- Low - 2xp

- Starts: Noon UTC Wednesday, Oct 25 2023
- Ends: Noon UTC Wednesday, Nov 01 2023

## Stats

- nSLOC: 143
- Complexity Score: 111

[//]: # (contest-details-open)

# Puppy Raffle

This project is to enter a raffle to win a cute dog NFT. The protocol should do the following:

1. Call the `enterRaffle` function with the following parameters:
   1. `address[] participants`: A list of addresses that enter. You can use this to enter yourself multiple times, or yourself and a group of your friends.
2. Duplicate addresses are not allowed
3. Users are allowed to get a refund of their ticket & `value` if they call the `refund` function
4. Every X seconds, the raffle will be able to draw a winner and be minted a random puppy
5. The owner of the protocol will set a feeAddress to take a cut of the `value`, and the rest of the funds will be sent to the winner of the puppy.

## Roles

Owner - Deployer of the protocol, has the power to change the wallet address to which fees are sent through the `changeFeeAddress` function.
Player - Participant of the raffle, has the power to enter the raffle with the `enterRaffle` function and refund value through `refund` function.

[//]: # (contest-details-close)

[//]: # (getting-started-open)

# Getting Started

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`

## Quickstart

```
git clone https://github.com/Cyfrin/2023-10-Puppy-Raffle
cd 2023-10-Puppy-Raffle
make
```

### Optional Gitpod

If you can't or don't want to run and install locally, you can work with this repo in Gitpod. If you do this, you can skip the `clone this repo` part.

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#github.com/Cyfrin/3-passwordstore-audit)

# Usage

## Testing

```
forge test
```

### Test Coverage

```
forge coverage
```

and for coverage based testing:

```
forge coverage --report debug
```

[//]: # (getting-started-close)

[//]: # (scope-open)

# Audit Scope Details

- Commit Hash: 22bbbb2c47f3f2b78c1b134590baf41383fd354f
- In Scope:

```
./src/
└── PuppyRaffle.sol
```

## Compatibilities

- Solc Version: 0.7.6
- Chain(s) to deploy contract to: Ethereum

[//]: # (scope-close)

[//]: # (known-issues-open)

# Known Issues

None

[//]: # (known-issues-close)


## Vulnerabilites

[H-1 Reentrancy attack in PuppyRaffle::refund allows entrant to drain raffle balance](Vulnerabilities.md#h-1-reentrancy-attack-in-puppyrafflerefund-allows-entrant-to-drain-raffle-balance) \
[H-2 Weak randomness in PuppyRaffle::selectWinner allows anyone to choose winner](Vulnerabilities.md#h-2-weak-randomness-in-puppyraffleselectwinner-allows-anyone-to-choose-winner) \
[H-3 Integer overflow of PuppyRaffle::totalFees loses fees](Vulnerabilities.md#h-3-integer-overflow-of-puppyraffletotalfees-loses-fees) \

[M-1 Denial of Service on PuppyRaffle::enterRaffle, as the looping through array to check for duplicates will increment gas costs for future entrants](Vulnerabilities.md#m-1-denial-of-service-on-puppyraffleenterraffle-as-the-looping-through-array-to-check-for-duplicates-will-increment-gas-costs-for-future-entrants) \
[M-2 Balance check on PuppyRaffle::withdrawFees enables griefers to selfdestruct a contract to send ETH to the raffle, blocking withdrawals](Vulnerabilities.md#m-2-balance-check-on-puppyrafflewithdrawfees-enables-griefers-to-selfdestruct-a-contract-to-send-eth-to-the-raffle-blocking-withdrawals) \
[M-3 Unsafe cast of PuppyRaffle::fee loses fees](Vulnerabilities.md#m-3-unsafe-cast-of-puppyrafflefee-loses-fees) \
[M-4 Smart Contract wallet raffle winners without a receive or a fallback will block the start of a new contest](Vulnerabilities.md#m-4-smart-contract-wallet-raffle-winners-without-a-receive-or-a-fallback-will-block-the-start-of-a-new-contest) \

[L-1 PuppyRaffle::getActivePlayerIndex returns 0 for non-existent players and players at index 0 causing players to incorrectly think they have not entered the raffle](Vulnerabilities.md#l-1-puppyrafflegetactiveplayerindex-returns-0-for-non-existent-players-and-players-at-index-0-causing-players-to-incorrectly-think-they-have-not-entered-the-raffle) \

[I-1 Solidity pragma should be specific, not wide](Vulnerabilities.md#i-1-passwordstore-getpassword)
[I-2 Using an Outdated Version of Solidity is Not Recommended](Vulnerabilities.md#i-2) \
[I-3 Missing checks for address(0) when assigning values to address state variables](Vulnerabilities.md#i-3-missing-checks-for-address0-when-assigning-values-to-address-state-variables) \
[I-4 PuppyRaffle::selectWinner does not follow CEI, which is not a best practice](Vulnerabilities.md#i-4-puppyraffleselectWinner-does-not-follow-cei-which-is-not-a-best-practice) \
[I-5 Use of "magic" numbers is discouraged](Vulnerabilities.md#i-5-use-of-magic-numbers-is-discouraged) \
[I-6 Test Coverage](Vulnerabilities.md#i-6-test-coverage) \
[I-7 State Changes are Missing Events](Vulnerabilities.md#i-7-state-changes-are-missing-events) \

[G-1 Unchanged state variables should be declared constant or immutable](Vulnerabilities.md#g-1-unchanged-state-variables-should-be-declared-constant-or-immutable) \
[G-2 Storage Variables in a Loop Should be Cached](Vulnerabilities.md#g-2-storage-variables-in-a-loop-should-be-cached) \
