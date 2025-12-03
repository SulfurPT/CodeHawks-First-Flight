# High

### [H-1] Deposit inconsistency in `BriVault::deposit` allows depositor to receive shares for self while staking for another


**Description:** The `BriVault::deposit(uint256 assets, address receiver)` function records the staked amount for `receiver` but mints ERC20 shares to `msg.sender`. This breaks accounting invariants: the vault believes `receiver` staked, but the depositor receives the shares.

```js
// BriVault::deposit
stakedAsset[receiver] = stakeAsset;
_mint(msg.sender, participantShares);
```

**Impact:** 
- Depositor can deposit on behalf of another address but get the shares for themselves.
- This allows the depositor to unfairly participate in events, claim rewards, or withdraw funds, effectively misappropriating tokens.
- Accounting inconsistencies can cascade to other functions relying on stakedAsset vs balanceOf.

**Proof of Concept:**

1. User2 approves and deposits 1 ether (mock ERC20 units) on behalf of user1.
2. `stakedAsset` is credited to user1, but ERC20 shares are minted to user2.
3. Inspect `stakedAsset` and balances.

<details>
<summary>PoC</summary>


Add the following to `briVault.t.sol`

```js

function test_POC_InconsistencyDeposit() public {
    uint256 depositAmount = 1 ether;

    // user2 approves and deposits on behalf of user1
    vm.prank(user2);
    mockToken.approve(address(briVault), depositAmount);

    vm.prank(user2);
    briVault.deposit(depositAmount, user1);

    // stakedAsset stored for receiver (user1), but shares minted to msg.sender (user2)
    uint256 stakedForUser1 = briVault.stakedAsset(user1);
    uint256 stakedForUser2 = briVault.stakedAsset(user2);
    uint256 sharesUser1 = briVault.balanceOf(user1);
    uint256 sharesUser2 = briVault.balanceOf(user2);

    // Assertions demonstrating inconsistency
    assertTrue(stakedForUser1 > 0, "stakedAsset for receiver should be > 0");
    assertEq(stakedForUser2, 0, "stakedAsset for depositor should be 0 (since receiver used)");
    assertEq(sharesUser1, 0, "receiver should not have received ERC20 shares");
    assertTrue(sharesUser2 > 0, "depositor unexpectedly received shares");

    // Optional console log
    console.log("stakedForUser1:", stakedForUser1);
    console.log("sharesUser2:", sharesUser2);
}
```

</details>

**Recommendation:** 
Mint shares to the `receiver` instead of `msg.sender` to align staked assets and ERC20 balances:

```diff
-    stakedAsset[receiver] = stakeAsset;
-    _mint(msg.sender, participantShares);
+    stakedAsset[receiver] = stakeAsset;
+    _mint(receiver, participantShares);

```



# Medium

### [M-1] `BriVault::joinEvent` allows duplicate joins inflating participant counters


**Description:** The `joinEvent(uint256 countryId)` function allows the same address to join multiple times.
Each call pushes `msg.sender` into `usersAddress` array, increments `numberOfParticipants` and increments `totalParticipantShares` by `balanceOf(msg.sender)`.

However, `userSharesToCountry[msg.sender][countryId]` is overwritten rather than accumulated, leading to inflated totals and duplicate entries.

```js
// BriVault::joinEvent
userSharesToCountry[msg.sender][countryId] = participantShares;
usersAddress.push(msg.sender);
numberOfParticipants++;
totalParticipantShares += participantShares;
```

**Impact:** 
- `numberOfParticipants` and `totalParticipantShares` can be inflated by repeated calls, breaking reward distribution logic.
- Array growth can lead to high gas costs and potential DoS attacks.
- Aggregate metrics no longer match individual share assignments.

**Proof of Concept:**

1. User3 approves and deposits 2 ether.
2. User3 calls `joinEvent(1)` twice.
3. Observe that `numberOfParticipants` and `totalParticipantShares` increase incorrectly.

<details>
<summary>PoC</summary>


Add the following to `briVault.t.sol`

```js

function test_POC_DuplicateJoin() public {
    uint256 depositAmount = 2 ether;

    // user3 approves and deposits
    vm.prank(user3);
    mockToken.approve(address(briVault), depositAmount);

    vm.prank(user3);
    briVault.deposit(depositAmount, user3);

    // First join
    vm.prank(user3);
    briVault.joinEvent(1);

    uint256 participantsAfterFirst = briVault.numberOfParticipants();
    uint256 totalParticipantSharesAfterFirst = briVault.totalParticipantShares();

    // Second join (duplicate)
    vm.prank(user3);
    briVault.joinEvent(1);

    uint256 participantsAfterSecond = briVault.numberOfParticipants();
    uint256 totalParticipantSharesAfterSecond = briVault.totalParticipantShares();

    // Assertions
    assertEq(participantsAfterSecond, participantsAfterFirst + 1, "numberOfParticipants should increase again (duplicate join)");
    assertTrue(totalParticipantSharesAfterSecond > totalParticipantSharesAfterFirst, "totalParticipantShares increased even though userSharesToCountry overwritten");

    // Confirm per-user shares remain unchanged
    uint256 recordedShares = briVault.userSharesToCountry(user3, 1);
    uint256 balanceShares = briVault.balanceOf(user3);
    assertEq(recordedShares, balanceShares, "userSharesToCountry equals balanceOf (but totalParticipantShares inflated)");
}
```

</details>

**Recommendation:** 
Add a duplicate-join guard to prevent multiple joins per address:

```diff
+   error AlreadyJoined();

    mapping(address => bool) public hasJoined;

    function joinEvent(uint256 countryId) public {
        if (hasJoined[msg.sender]) revert AlreadyJoined();
+       hasJoined[msg.sender] = true;
        // Existing logic
    }

```

Optionally, maintain per-country totals instead of iterating over `usersAddress` to reduce gas costs:

```diff
    mapping(uint256 => uint256) public countryTotalShares;

    function joinEvent(uint256 countryId) public {
        ...
        userSharesToCountry[msg.sender][countryId] = participantShares;
        countryTotalShares[countryId] += participantShares;
        ...
    }

    function _getWinnerShares() internal view returns (uint256) {
-       uint256 totalWinnerShares = 0;
-       for (uint256 i = 0; i < usersAddress.length; ++i) {
-           totalWinnerShares += userSharesToCountry[usersAddress[i]][winnerCountryId];
-       }
-       return totalWinnerShares;
+       return countryTotalShares[winnerCountryId];
    }
```



### [M-2] `BriVault::withdraw` can revert due to division by zero when total participant shares are zero


**Description:** The `withdraw()` function calculates the user’s share using a division by `totalParticipantShares`.
If no participants have joined the event yet (or `totalParticipantShares` is zero), the division will revert with a panic (`division by zero`).

```js
// BriVault::withdraw
uint256 userShare = (balanceOf(msg.sender) * eventBalance) / totalParticipantShares;
```

**Impact:** 
- Users are unable to withdraw funds when `totalParticipantShares` is zero.
- This creates a Denial-of-Service (DoS) vector for the withdraw function.
- No direct theft of funds occurs, but it can block legitimate withdrawals and disrupt event logic.

**Proof of Concept:**

1. User1 deposits tokens and joins the event.
2. Owner sets the winner and totalParticipantShares is zero.
3. User1 attempts to withdraw.
4. Transaction reverts with panic 0x12 (division by zero).

<details>
<summary>PoC</summary>


Add the following to `briVault.t.sol`

```js
function test_POC_WithdrawDivByZero() public {
    uint256 depositAmount = 1 ether;

    // user1 approves and deposits
    vm.prank(user1);
    mockToken.approve(address(briVault), depositAmount);

    vm.prank(user1);
    briVault.deposit(depositAmount, user1);

    // user1 joins event
    vm.prank(user1);
    briVault.joinEvent(0);

    // warp time to after event ends
    vm.warp(block.timestamp + 2 weeks);

    // owner sets winner (no shares accumulated yet)
    vm.prank(owner);
    briVault.setWinner(5);

    // expect revert when user1 tries to withdraw
    vm.prank(user1);
    vm.expectRevert();
    briVault.withdraw();
}
```

</details>

**Recommendation:** 
Add a check to ensure `totalParticipantShares > 0` before dividing, to prevent a division by zero:


```diff
- uint256 userShare = (balanceOf(msg.sender) * eventBalance) / totalParticipantShares;
+ if (totalParticipantShares == 0) revert NoShares();
+ uint256 userShare = (balanceOf(msg.sender) * eventBalance) / totalParticipantShares;

```



### [M-3] `BriVault::joinEvent` allows joining with an empty country ID


**Description:** The `joinEvent(uint256 countryId)` function does not validate the `_countryId` parameter.
A user can join an event specifying a `countryId` of `0` (or any invalid ID), which might represent a non-existent country.

```js
// BriVault::joinEvent
userSharesToCountry[msg.sender][countryId] = participantShares;
usersAddress.push(msg.sender);
numberOfParticipants++;
totalParticipantShares += participantShares;
```

**Impact:** 
- Users can join events with invalid country IDs, potentially breaking reward distribution logic.
- Metrics like `userSharesToCountry` and `totalParticipantShares` may become inconsistent with real-world expectations.
- Downstream calculations assuming valid country IDs could behave incorrectly or be exploited for edge-case manipulations.

**Proof of Concept:**

1. User1 deposits tokens.
2. User1 calls `joinEvent(0)` with an empty country ID.
3. Observe that `joinedEvent` is emitted and `userSharesToCountry` is recorded for country `0`.

<details>
<summary>PoC</summary>


Add the following to `briVault.t.sol`

```js
function test_POC_EmptyCountryJoin() public {
    uint256 depositAmount = 1 ether;

    // user1 approves and deposits
    vm.prank(user1);
    mockToken.approve(address(briVault), depositAmount);

    vm.prank(user1);
    briVault.deposit(depositAmount, user1);

    // user1 joins event with empty countryId
    vm.prank(user1);
    briVault.joinEvent(0);

    // Assertions
    uint256 recordedShares = briVault.userSharesToCountry(user1, 0);
    uint256 balanceShares = briVault.balanceOf(user1);

    assertEq(recordedShares, balanceShares, "userSharesToCountry recorded even with empty countryId");
    assertEq(briVault.numberOfParticipants(), 1, "numberOfParticipants incremented");
}
```

</details>

**Recommendation:** 
Validate the `_countryId` to ensure it corresponds to a valid country. For example:

```diff
+   error InvalidCountryId();
+
    function joinEvent(uint256 countryId) public {
+       if (countryId == 0) revert InvalidCountryId();
        // existing logic
    }

```


### [M-4] `BriVault::setWinner` can run out of gas for large number of participants (Gas DoS)


**Description:** `The setWinner()` function iterates over all participants to calculate total winner shares:

```js
for (uint256 i = 0; i < usersAddress.length; ++i){
    address user = usersAddress[i]; 
    totalWinnerShares += userSharesToCountry[user][winnerCountryId];
}
```
When the number of participants is very large (thousands), this loop consumes a high amount of gas. This can cause the transaction to run out of gas, effectively preventing the owner from setting the winner and finalizing the vault.

**Impact:** 
- For a large number of participants, `setWinner()` may revert due to gas limits, creating a Denial-of-Service (DoS) scenario.
- No direct theft of funds occurs, but participants may be blocked from withdrawing their rewards until the issue is resolved.
- Risk is higher in events with thousands of participants, while small events are unaffected.

**Proof of Concept:**

1. Create 5,000 fake participants and have each deposit + join the event.
2. Warp time to after the event ends.
3. Owner calls setWinner().
4. Transaction reverts due to gas limit.

<details>
<summary>PoC</summary>


Add the following to `briVault.t.sol`

```js
function test_POC_SetWinnerGasDoS() public {
    // create N fake users and have them deposit + join (N large)
    for (uint i=0; i<5000; i++) {
        address a = makeAddr(string(abi.encodePacked("u", vm.toString(i))));
        mockToken.mint(a, 1 ether);
        vm.prank(a);
        mockToken.approve(address(briVault), 1 ether);
        vm.prank(a);
        briVault.deposit(1 ether, a);
        vm.prank(a);
        briVault.joinEvent(1);
    }

        // gas consumed by setWinner
    uint256 gasStart = gasleft();
    vm.warp(eventEndDate + 1);
    vm.prank(owner);
    briVault.setWinner(1);
    uint256 gasUsed = gasStart - gasleft();

    console.log("Gas consumed by setWinner with 5000 users:", gasUsed);


}
```

</details>

**Recommendation:** 
Avoid iterating over unbounded arrays on-chain and consider batch processing, mapping-based aggregation, or off-chain computation to calculate winner shares.


```diff
- for (uint256 i = 0; i < usersAddress.length; ++i){
-     address user = usersAddress[i]; 
-     totalWinnerShares += userSharesToCountry[user][winnerCountryId];
- }
+ // Possible mitigation:
+ // 1. Maintain a running total per country on joinEvent()
+ // 2. Or split setWinner() into multiple transactions to handle batches

```