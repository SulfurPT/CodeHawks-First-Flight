# 🚀 CodeHawks First Flight 🦅

<<<<<<< HEAD
Welcome to my **CodeHawks First Flight** repository! This repository contains my solutions and detailed analyses of the **CodeHawks First Flight** challenges from Cyfrin. The First Flight challenges are designed to help beginners dive into the world of **smart contract auditing**, providing hands-on experience with real-world security flaws and vulnerabilities.
=======
- [First Flight #1: PasswordStore](#first-flight-1-passwordstore)
  - [Contest Details](#contest-details)
  - [Stats](#stats)
  - [About](#about)
  - [Roles](#roles)
  - [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Quickstart](#quickstart)
    - [Optional Gitpod](#optional-gitpod)
  - [Usage](#usage)
    - [Deploy (local)](#deploy-local)
  - [Testing](#testing)
    - [Test Coverage](#test-coverage)
  - [Scope](#scope)
  - [Compatibilities](#compatibilities)
  - [Known Issues](#known-issues)
  - [Vulnerabilites](#vulnerabilites)
>>>>>>> 42c2c88 (Add the FirstFly PasswordStore Audit)

## 🎯 What’s Inside?
Each challenge has its own dedicated folder, containing:
- ✅ **Smart contract source code** (from the challenge)
- ✅ **Test cases and exploit scripts** used during the process
- ✅ A detailed **README** explaining the contract
- ✅ A **Vulnerabilities.md** listing and explaining the vulnerabilities I've discovered

## 🔥 Why This Repository?
As part of my journey to become an expert in **smart contract auditing**, this repository is a record of my progress through the **CodeHawks First Flight** challenges. It serves as both a learning tool for me and a potential resource for anyone interested in improving their skills in blockchain security.

## 💡 What Will We Learn Here?
- In-depth analysis of common smart contract vulnerabilities
- Practical steps for auditing and exploitation
- How to identify weaknesses in smart contracts and develop secure code

## ⚡ Want to Learn More?
Check out the individual challenges to see how I approached each one, the vulnerabilities I found, and the insights I gained.

🔗 *Stay curious, break things, and always keep learning!*

<<<<<<< HEAD
=======
## Stats

- nSLOC: 20
- Complexity Score: 10

## About

PasswordStore is a smart contract application for storing a password. Users should be able to store a password and then retrieve it later. Others should not be able to access the password.

## Roles

Owner - Only the owner may set and retrieve their password

[//]: # (contest-details-close)

[//]: # (getting-started-open)

## Getting Started

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`

## Quickstart

```
git clone https://github.com/Cyfrin/2023-10-PasswordStore
cd 2023-10-PasswordStore
​forge install foundry-rs/forge-std --no-commit
forge build
```

### Optional Gitpod

If you can't or don't want to run and install locally, you can work with this repo in Gitpod. If you do this, you can skip the `clone this repo` part.

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#github.com/Cyfrin/3-passwordstore-audit)

## Usage

### Deploy (local)

1. Start a local node

```
make anvil
```

2. Deploy

This will default to your local node. You need to have it running in another terminal in order for it to deploy.

```
make deploy
```

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

## Scope

- Commit Hash: 2e8f81e263b3a9d18fab4fb5c46805ffc10a9990
- In Scope:

```
./src/
└── PasswordStore.sol
```

## Compatibilities

- Solc Version: 0.8.18
- Chain(s) to deploy contract to: Ethereum

[//]: # (scope-close)

## Known Issues

[//]: # (known-issues-open)

<p align="center">
No known issues reported.

[//]: # (known-issues-close)


## Vulnerabilites

[H-1 Variable password is visible to anyone on-chain](Vulnerabilities.md#h-1-variable-password-is-visible-to-anyone-on-chain)
[H-2 `PasswordStore::setPassword` has no access controls, meaning a non-owner could change the password](Vulnerabilities.md#h-2-passwordstore-setpassword-has-no-access-controls-meaning-a-non-owner-could-change-the-password)
[I-1 The `PasswordStore::getPassword` natspec indicates a parameter that doesn't exist, causing the natspec to be incorrect.](Vulnerabilities.md#i-1-passwordstore-getpassword)
>>>>>>> 42c2c88 (Add the FirstFly PasswordStore Audit)
