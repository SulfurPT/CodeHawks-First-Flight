### Out-of-Bounds Access Risk in `InheritanceManager::onlyBeneficiaryWithIsInherited` Modifier Due to Unbounded Loop

**Description:** 
The `InheritanceManager::onlyBeneficiaryWithIsInherited` modifier uses an unbounded loop that iterates beyond the `beneficiaries` array bounds, risking out-of-bounds access, transaction reverts, and gas inefficiency. This introduces vulnerabilities in access control logic and exposes the contract to denial-of-service (DoS) attacks via gas exhaustion.

The modifier’s while loop runs `beneficiaries.length + 1` times, attempting to access `beneficiaries[i]` when `i = beneficiaries.length`. Since Solidity arrays are zero-indexed, this guarantees an out-of-bounds exception, causing the transaction to revert.

Additionally, looping over a dynamic-length array in modifiers is inherently gas-inefficient and risky, as large `beneficiaries` arrays could cause gas limits to be exceeded.

**Impact:** 

Medium Severity

Guaranteed Reverts: Transactions using this modifier will revert due to out-of-bounds access, breaking core functionality.

Access Control Bypass: If the loop is intended to validate `msg.sender`, legitimate `beneficiaries` may be denied access.

Gas Exhaustion: Unbounded loops waste gas and could lead to DoS during high network congestion.

**Tolls Used:** 
Manual code review

**Proof of Concept:**
N/A

**Recommended Mitigation:** 

Change the loop condition to i < beneficiaries.length to prevent out-of-bounds access:

```Solidity
while (i < beneficiaries.length) { ... }
```
Split the isInherited check from beneficiary validation to simplify logic:

```Solidity
modifier onlyBeneficiaryWithIsInherited() {
    require(isInherited, "Inheritance not active");
    require(isBeneficiary[msg.sender], "Unauthorized");
    _;
}

```

Replace array iteration with a mapping for efficient beneficiary checks:

```Solidity
mapping(address => bool) public isBeneficiary;
modifier onlyBeneficiaryWithIsInherited() {
    require(isBeneficiary[msg.sender] && isInherited, "Unauthorized");
    _;
}
```

These changes eliminate the vulnerability while improving code readability and gas efficiency.






### Missing Access Control in `InheritanceManager::withdrawInheritedFunds` Allows Non-Beneficiaries to Trigger Payouts

**Description:** 
The `InheritanceManager::withdrawInheritedFunds` function lacks proper access control, enabling any address (including non-beneficiaries) to trigger fund withdrawals. While beneficiaries ultimately receive funds, this violates intended authorization logic and exposes the contract to unnecessary external interference.

The `InheritanceManager::withdrawInheritedFunds` function does not enforce a check to ensure the caller is a beneficiary. In the provided PoC, user4 (not a beneficiary) successfully triggers withdrawals after the inheritance period.


**Impact:** 
Low Severity

Theres no steal of funds but non-beneficiaries can forcibly initiate withdrawals, potentially disrupting planned fund distribution schedules.

**Tolls Used:** 
Manual code review
Foundry test case (provided by the user)

**Proof of Concept:**

```Solidity

    function test_withdrawFunds() public {
        address owner = makeAddr("owner");
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        address user4 = makeAddr("user4");
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        im.addBeneficiery(user3);
        vm.stopPrank();
        vm.warp(1);
        vm.deal(address(im), 9e18);
        vm.warp(1 + 91 days);
        // user4 is not a beneficiaries
        vm.startPrank(user4);
        im.inherit();
        im.withdrawInheritedFunds(address(0));
        vm.stopPrank();
        assertEq(9e18, user1.balance);
        assertEq(9e18, user2.balance);
        assertEq(9e18, user3.balance);
 }
```

**Recommended Mitigation:** 

Ensure that `InheritanceManager::onlyBeneficiaryWithIsInherited` is working as intented






### Early Return in `InheritanceManager::buyOutEstateNFT` Prevents NFT Burning, Enabling Infinite Buy-Outs

**Description:** 

The `InheritanceManager::buyOutEstateNFT` function contains an early return statement when the caller is identified as a beneficiary. This skips the critical `nft.burnEstate(_nftID)` call, leaving the NFT unburned and allowing repeated buy-outs. Additionally, the payment distribution logic is flawed, underpaying beneficiaries.

**Impact:** 
High Severity

The NFT’s intended "burn-after-purchase" mechanism is broken, rendering the system’s economic model nonfunctional user can repeatedly call `InheritanceManager::buyOutEstateNFT` on the same NFT.

**Tolls Used:** 
Manual code review
Foundry test case (provided by the user)

**Proof of Concept:**

1 - The test shows `user1`, `user2`, and `user3` each call `InheritanceManager::buyOutEstateNFT(1)`, spending 20 USDC each.

2 - The NFT (ID 1) is never burned, as confirmed by the absence of `NFTFactory::burnEstate` calls in the InheritanceManager logic.

```Solidity
function test_buyOutEstateNFTMultiple() public {
        address owner = makeAddr("owner");
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        im.addBeneficiery(user3);
        im.createEstateNFT("our beach-house", 20, address(usdc));
        vm.stopPrank();
        usdc.mint(user1, 20);
        usdc.mint(user2, 20);
        usdc.mint(user3, 20);

        vm.warp(1 + 90 days);

        vm.startPrank(user1);
        usdc.approve(address(im), 20);
        im.inherit();
        im.buyOutEstateNFT(1);
        vm.stopPrank();

        vm.startPrank(user2);
        usdc.approve(address(im), 20);
        im.inherit();
        im.buyOutEstateNFT(1);
        vm.stopPrank();

        vm.startPrank(user3);
        usdc.approve(address(im), 20);
        im.inherit();
        im.buyOutEstateNFT(1);
        vm.stopPrank();
    }
```

**Recommended Mitigation:** 

Ensure the NFT is burned after processing payments:

```diff

Ensure the NFT is burned after processing payments:

    function buyOutEstateNFT(uint256 _nftID) external onlyBeneficiaryWithIsInherited {
        uint256 value = nftValue[_nftID];
        uint256 divisor = beneficiaries.length;
        uint256 multiplier = beneficiaries.length - 1;
        uint256 finalAmount = (value / divisor) * multiplier;
        IERC20(assetToPay).safeTransferFrom(msg.sender, address(this), finalAmount);
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            if (msg.sender == beneficiaries[i]) {
-                return;
-            } else {
                IERC20(assetToPay).safeTransfer(beneficiaries[i], finalAmount / divisor);
            }
        }
        nft.burnEstate(_nftID);
    }

```







### Precision Loss and Incorrect Fund Distribution in `InheritanceManager::buyOutEstateNFT` and `InheritanceManager::withdrawInheritedFundsLeaves` Stale Funds in Contract

**Description:** 

Both `InheritanceManager::buyOutEstateNFT` and `InheritanceManager::withdrawInheritedFundsLeaves` functions use integer division without remainder handling, leading to permanently locked ETH/tokens in the contract. This affects all asset distributions, violating the protocol’s intent to fully disburse funds to beneficiaries.

**Impact:** 
High Severity

Stale Funds: Residual tokens accumulate in the contract, permanently locked.

Beneficiary Losses: Users receive fewer tokens than entitled, proportional to the truncation error.

**Proof of Concept:**

withdrawInheritedFunds 

```Solidity
    function test_withdrawFunds() public {
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        im.addBeneficiery(user3);
        vm.stopPrank();
        vm.warp(1);
        vm.deal(address(im), 20);
        console.log("Money on the contract before the division to the Beneficieries:", address(im).balance);
        vm.warp(1 + 91 days);
        vm.startPrank(user1);
        im.inherit();
        im.withdrawInheritedFunds(address(0));
        vm.stopPrank();
        console.log("User1 have after the division:", user1.balance);
        console.log("User2 have after the division:", user2.balance);
        console.log("User3 have after the division:", user3.balance);
        console.log("Money on the contract after the division:", address(im).balance);
    }

```

```
[PASS] test_withdrawFundsDivision() (gas: 276902)
Logs:
  Money on the contract before the division to the Beneficieries: 20
  User1 have after the division: 6
  User2 have after the division: 6
  User3 have after the division: 6
  Money on the contract after the division: 2
```

buyOutEstateNFT 



**Recommended Mitigation:** 

Restructure payments to collect exactly value tokens from the caller and distribute all tokens proportionally:

For withdrawInheritedFunds:

```diff
function withdrawInheritedFunds(address _asset) external {
    if (!isInherited) {
        revert NotYetInherited();
    }
    uint256 divisor = beneficiaries.length;
    if (_asset == address(0)) {
        uint256 ethAmountAvailable = address(this).balance;
        uint256 amountPerBeneficiary = ethAmountAvailable / divisor;
+       uint256 remainder = ethAmountAvailable % divisor;
        for (uint256 i = 0; i < divisor; i++) {
            address payable beneficiary = payable(beneficiaries[i]);
-           (bool success,) = beneficiary.call{value: amountPerBeneficiary}("");
+           uint256 amountToSend = amountPerBeneficiary + (i == 0 ? remainder : 0);
+           (bool success,) = beneficiary.call{value: amountToSend}("");
            require(success, "something went wrong");
        }
    } else {
        uint256 assetAmountAvailable = IERC20(_asset).balanceOf(address(this));
        uint256 amountPerBeneficiary = assetAmountAvailable / divisor;
+       uint256 remainder = assetAmountAvailable % divisor;
        for (uint256 i = 0; i < divisor; i++) {
-           IERC20(_asset).safeTransfer(beneficiaries[i], amountPerBeneficiary);
+           uint256 amountToSend = amountPerBeneficiary + (i == 0 ? remainder : 0);
+           IERC20(_asset).safeTransfer(beneficiaries[i], amountToSend);
        }
    }
}

```

For buyOutEstateNFT:


```diff
function buyOutEstateNFT(uint256 _nftID) external onlyBeneficiaryWithIsInherited {
    uint256 value = nftValue[_nftID];
    uint256 divisor = beneficiaries.length;
-   uint256 multiplier = beneficiaries.length - 1;
-   uint256 finalAmount = (value / divisor) * multiplier;
-   IERC20(assetToPay).safeTransferFrom(msg.sender, address(this), finalAmount);
+   uint256 paymentPerBeneficiary = value / divisor;
+   uint256 remainder = value % divisor;
+   IERC20(assetToPay).safeTransferFrom(msg.sender, address(this), value);
    for (uint256 i = 0; i < beneficiaries.length; i++) {
        if (msg.sender == beneficiaries[i]) {
            return;
        } else {
-           IERC20(assetToPay).safeTransfer(beneficiaries[i], finalAmount / divisor);
+           uint256 amountToSend = paymentPerBeneficiary + (i == 0 ? remainder : 0);
+           IERC20(assetToPay).safeTransfer(beneficiaries[i], amountToSend);
        }
    }
    nft.burnEstate(_nftID);
}

```

**End** 


### Improper Beneficiary Removal Leaves Zero Address in Array, Enabling Irreversible Fund Loss

**Description:** 
The `InheritanceManager::removeBeneficiary` function does not correctly manage the beneficiaries array, leaving a zero address in the array after removal. This causes subsequent fund distributions (e.g., in `InheritanceManager::buyOutEstateNFT` and `InheritanceManager::withdrawInheritedFunds`) to send tokens to the zero address, permanently burning funds.

**Impact:** 
High Severity

Permanent Fund Loss: Tokens sent to the zero address are irretrievable.

Incorrect Distribution Logic: The presence of a zero address skews payment calculations (e.g., `beneficiaries.length` includes invalid entries).

**Proof of Concept:**

```Solidity
    function test_withdrawFundsRemoveBeneficiary() public {
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        im.addBeneficiery(user3);
        im.removeBeneficiary(user2);
        vm.stopPrank();
        vm.warp(1);
        vm.deal(address(im), 20);
        console.log("Money on the contract before the division to the Beneficieries:", address(im).balance);
        vm.warp(1 + 91 days);
        vm.startPrank(user1);
        im.inherit();
        im.withdrawInheritedFunds(address(0));
        vm.stopPrank();
        console.log("User1 have after the division:", user1.balance);
        console.log("User2 have after the division:", user2.balance);
        console.log("User3 have after the division:", user3.balance);
        console.log("Contract 0 have after the division:", address(0x0).balance);
        console.log("Money on the contract after the division:", address(im).balance);
    }
```

**Recommended Mitigation:** 

Replace the beneficiary to be removed with the last element in the array and then call .pop() to delete the last entry.

```diff
function removeBeneficiary(address _beneficiary) external onlyOwner {
    uint256 indexToRemove = _getBeneficiaryIndex(_beneficiary);
-     delete beneficiaries[indexToRemove];
+     beneficiaries[indexToRemove] = beneficiaries[beneficiaries.length - 1];
+     beneficiaries.pop();
}
```






### Premature Inheritance Due to Stale Deadline in `InheritanceManager::createEstateNFT` and `InheritanceManager::contractInteractions`

**Description:** 
The `InheritanceManager::createEstateNFT` and `InheritanceManager::contractInteractions` functions fail to update the inheritance deadline, causing the system to incorrectly classify active accounts as dormant. This allows beneficiaries to trigger inheritance even if the owner is actively managing assets.

**Impact:** 
High Severity

Premature Asset Inheritance: Legitimate owners risk losing control of assets due to a stale deadline, even while actively using the protocol.

**Tools Used:**
Manual Review

**Recommendations:**
Incorporate a deadline update by `calling _setDeadline()` at the end of these functions.



### Unilateral Trustee Appointment Enables Arbitrary NFT Devaluation for Malicious Buy-Outs

**Description:** 
The `appointTrustee` function allows any single beneficiary to appoint a trustee without consensus. A malicious beneficiary can collude with a trustee to drastically reduce NFT values via `setNftValue`, enabling them to purchase assets at artificially low prices, stealing value from other beneficiaries.

**Impact:** 
High Severity

Theft of Shared Assets: Attackers can buy NFTs for pennies on the dollar, bypassing fair market value

**Proof of Concept:**

```Solidity

    function test_TrusteeCanChangeValues() public {
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        im.createEstateNFT("our beach-house", 20, address(usdc));
        vm.stopPrank();
        vm.warp(1 + 90 days);
        vm.startPrank(user2);
        im.inherit();
        im.appointTrustee(user3);
        vm.stopPrank();
        vm.startPrank(user3);
        im.setNftValue(1, 5);
    }

```

**Recommended Mitigation:** 
Implement a consensus mechanism ensuring that a majority of beneficiaries approve any trustee assignment.


### Flawed Loop Logic in buyOutEstateNFT Skips Payments to Most Beneficiaries, Enabling Caller to Retain Funds

**Description:** 
The buyOutEstateNFT function contains an early return when encountering the caller’s address in the beneficiaries array. This skips payments to all beneficiaries listed after the caller that acquiring the NFT.

**Impact:** 

High Severity

Theft of Beneficiary Funds: Only beneficiaries positioned before the caller in the array receive payments; others are ignored.

**Proof of Concept:**

```Solidity
    function test_OnlyUserinFrontIsPayed() public {
        vm.startPrank(owner);
        im.addBeneficiery(user1);
        im.addBeneficiery(user2);
        im.addBeneficiery(user3);
        im.addBeneficiery(user4);
        im.createEstateNFT("our beach-house", 23, address(usdc));
        vm.stopPrank();
        usdc.mint(user2, 15);
        vm.warp(1 + 90 days);
        vm.startPrank(user2);
        usdc.approve(address(im), 20);
        im.inherit();
        im.buyOutEstateNFT(1);
        vm.stopPrank();

        console.log("User1 will have:", usdc.balanceOf(user1));
        console.log("User2 will have:", usdc.balanceOf(user2));
        console.log("User3 will have:", usdc.balanceOf(user3));
        console.log("User4 will have:", usdc.balanceOf(user4));
    }
```

Log

```
Ran 1 test for test/Mytest.t.sol:Testcontract
[PASS] test_OnlyUserinFrontIsPayed() (gas: 438575)
Logs:
  User1 will have: 3
  User2 will have: 0
  User3 will have: 0
  User4 will have: 0

```

**Recommended Mitigation:** 

Remove Early Return and Track Caller

```dif

    function buyOutEstateNFT(uint256 _nftID) external onlyBeneficiaryWithIsInherited {
        uint256 value = nftValue[_nftID];
        uint256 divisor = beneficiaries.length;
        uint256 multiplier = beneficiaries.length - 1;
        uint256 finalAmount = (value / divisor) * multiplier;
        IERC20(assetToPay).safeTransferFrom(msg.sender, address(this), finalAmount);
        for (uint256 i = 0; i < beneficiaries.length; i++) {
-           if (msg.sender == beneficiaries[i]) {
-               return;
-           } else {
+               if (beneficiaries[i] != msg.sender) {    
                IERC20(assetToPay).safeTransfer(beneficiaries[i], finalAmount / divisor);
            }
        }
        nft.burnEstate(_nftID);
    }
```





