# High

### [H-1] Incorrect Event Parameter Order


**Description:** 
The `TokensWithdrawn` event declaration and emission have mismatched parameter orders, causing off-chain systems to misinterpret event data. The event is declared with parameters `(token, to, amount)` but emitted as `(to, token, amount)`. This parameter swap creates critical data integrity issues for any system monitoring contract events.


```js
// Event declared with parameters: (token, to, amount)
event TokensWithdrawn(address indexed token, address indexed to, uint256 amount);

// But emitted with parameters: (to, token, amount) 
emit TokensWithdrawn(to, token, amount);
```

**Impact:** 
- Off-chain monitoring systems will misinterpret token withdrawal events
- Indexed parameters will be incorrectly parsed
- Event tracking and analytics will show wrong data

**Proof of Concept:**



<details>
<summary>PoC</summary>


Add the following to `RebateFiHookTest.t.sol`

The test shows the event is emitted with parameters in the wrong order, which will cause off-chain systems to misinterpret the token and recipient addresses.

```js

function test_TokensWithdrawnEventParameterOrder() public {
    reFiToken.mint(address(rebateHook), 100 ether);
    
    vm.expectEmit(true, true, false, true);
    // Expected: (token, to, amount) but actual: (to, token, amount)
    emit ReFiSwapRebateHook.TokensWithdrawn(address(this), address(reFiToken), 100 ether);
    
    rebateHook.withdrawTokens(address(reFiToken), address(this), 100 ether);
}
```

</details>

**Recommendation:** 


```diff
function withdrawTokens(address token, address to, uint256 amount) external onlyOwner {
    IERC20(token).transfer(to, amount);
-   emit TokensWithdrawn(to, token, amount);
+   emit TokensWithdrawn(token, to, amount);
}
```

### [H-2] Missing Zero Address Validation


**Description:** 
The `withdrawTokens` function lacks validation for the recipient address, allowing tokens to be permanently burned by sending them to `address(0)`. This represents irreversible fund loss that cannot be recovered through any means.

```js
function withdrawTokens(address token, address to, uint256 amount) external onlyOwner {
@>  IERC20(token).transfer(to, amount); // No validation for `to` parameter
    emit TokensWithdrawn(to, token, amount);
}
```

**Impact:** 
- Tokens sent to `address(0)` are irrecoverable
- No validation prevents accidental destruction of funds  
- Users cannot rely on contract safety measures


**Proof of Concept:**



<details>
<summary>PoC</summary>


Add the following to `RebateFiHookTest.t.sol`

```js
function test_WithdrawTokensToZeroAddress() public {
    reFiToken.mint(address(rebateHook), 100 ether);
    
    // Successfully transfers 100 ETH to zero address
    rebateHook.withdrawTokens(address(reFiToken), address(0), 100 ether);
    assertEq(reFiToken.balanceOf(address(0)), 100 ether); // Funds permanently lost
}

```

</details>

**Recommendation:** 


```diff
function withdrawTokens(address token, address to, uint256 amount) external onlyOwner {
+   require(to != address(0), "Cannot withdraw to zero address");
+   require(token != address(0), "Invalid token address");
    IERC20(token).transfer(to, amount);
    emit TokensWithdrawn(token, to, amount);
}
```


### [H-3] Extreme Fee Setting Without Bounds


**Description:** 
The `ChangeFee` function lacks bounds validation, allowing the owner to set economically destructive fee percentages up to 16,777,215%. This could completely disable the protocol's swap functionality and undermine the entire economic model.

```js
function ChangeFee(bool _isBuyFee, uint24 _buyFee, bool _isSellFee, uint24 _sellFee) external onlyOwner {
@>  if(_isBuyFee) buyFee = _buyFee;        // No validation
@>  if(_isSellFee) sellFee = _sellFee;     // No validation
}
```

**Impact:** 
- Owner can set 100%+ fees, blocking all swaps
- Economic denial of service
- Potential abuse if owner keys are compromised


**Proof of Concept:**



<details>
<summary>PoC</summary>


Add the following to `RebateFiHookTest.t.sol`

```js
function test_OwnerCanSetExtremeFees() public {
    // Owner can set fees to 1,000,000% (1000x)
    rebateHook.ChangeFee(true, 1000000, true, 1000000);
    
    (uint24 buyFee, uint24 sellFee) = rebateHook.getFeeConfig();
    assertEq(buyFee, 1000000);  // 1000% fee
    assertEq(sellFee, 1000000); // 1000% fee
}

function test_OwnerCanSet100PercentFee() public {
    rebateHook.ChangeFee(false, 0, true, 100000); // 100% sell fee
    (uint24 buyFee, uint24 sellFee) = rebateHook.getFeeConfig();
    assertEq(sellFee, 100000); // Effectively blocks selling
}

```

</details>

**Recommendation:** 


```diff
function ChangeFee(bool _isBuyFee, uint24 _buyFee, bool _isSellFee, uint24 _sellFee) external onlyOwner {
    if(_isBuyFee) {
+       require(_buyFee <= 100000, "Buy fee cannot exceed 100%");
        buyFee = _buyFee;
    }
    if(_isSellFee) {
+       require(_sellFee <= 100000, "Sell fee cannot exceed 100%");
        sellFee = _sellFee;
    }
}
```

### [H-4] Logical Bug in Pool Validation


**Description:** 
The `_beforeInitialize` function contains a critical logical error with duplicate conditions that only check `currency1`, completely ignoring `currency0`. This breaks the fundamental requirement that pools must contain the ReFi token.

```js
function _beforeInitialize(address, PoolKey calldata key, uint160) internal view override returns (bytes4) {
    // Duplicate condition - only checks currency1 twice!
@>  if (Currency.unwrap(key.currency1) != ReFi && 
@>      Currency.unwrap(key.currency1) != ReFi) { // Should check currency0
        revert ReFiNotInPool();
    }
    return BaseHook.beforeInitialize.selector;
}
```

**Impact:** 
- Incorrect pool validation logic
- May allow pools without ReFi token or block valid pools
- Hook may not function as intended


**Proof of Concept:**



<details>
<summary>PoC</summary>


Add the following to `RebateFiHookTest.t.sol`

```js
function test_BeforeInitializeValidationLogic() public {
    PoolKey memory invalidKey = PoolKey({
        currency0: ethCurrency,
        currency1: tokenCurrency, // Not ReFi token
        fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
        tickSpacing: 60,
        hooks: rebateHook
    });
    
    vm.expectRevert(); // Reverts due to flawed logic
    manager.initialize(invalidKey, INITIAL_SQRT_PRICE);
}

```

</details>

**Recommendation:** 


```diff
function _beforeInitialize(address, PoolKey calldata key, uint160) internal view override returns (bytes4) {
-   if (Currency.unwrap(key.currency1) != ReFi && 
-       Currency.unwrap(key.currency1) != ReFi) {
+   if (Currency.unwrap(key.currency0) != ReFi && 
+       Currency.unwrap(key.currency1) != ReFi) {
        revert ReFiNotInPool();
    }
    return BaseHook.beforeInitialize.selector;
}
```

### [H-5] Centralization Risks - Owner Can Drain All Funds


**Description:** 
The contract owner has unlimited, immediate withdrawal capabilities without any safeguards, creating extreme centralization risks that could lead to complete fund loss if the owner is compromised or acts maliciously.

```js
function withdrawTokens(address token, address to, uint256 amount) external onlyOwner {
    IERC20(token).transfer(to, amount); // No limits or timelock
}
```

**Impact:** 
- Immediate fund drainage by owner
- No protection against malicious or compromised owner
- Users cannot trust funds stored in the contract

**Proof of Concept:**



<details>
<summary>PoC</summary>


Add the following to `RebateFiHookTest.t.sol`

```js
function test_OwnerCanDrainAllFunds() public {
    uint256 hookBalance = 500 ether;
    reFiToken.mint(address(rebateHook), hookBalance);
    
    uint256 initialBalance = reFiToken.balanceOf(address(this));
    rebateHook.withdrawTokens(address(reFiToken), address(this), hookBalance);
    
    uint256 finalBalance = reFiToken.balanceOf(address(this));
    assertEq(finalBalance, initialBalance + hookBalance);
    assertEq(reFiToken.balanceOf(address(rebateHook)), 0); // All funds drained
}

```

</details>

**Recommendation:** 

- Implement timelock for withdrawals
- Add maximum withdrawal limits
- Consider multi-signature requirements for large withdrawals
- Implement emergency withdrawal patterns with delays


# Medium


### [M-1] Fee Calculation Precision Loss


**Description:** 
The fee calculation mechanism uses integer division which causes precision loss for small swap amounts, potentially allowing fee avoidance through micro-transactions and undermining the protocol's revenue model.

```js
        if (isReFiBuy) {
            fee = buyFee;    
            emit ReFiBought(sender, swapAmount);
        } else {
            fee = sellFee;
            uint256 feeAmount = (swapAmount * sellFee) / 100000;
            emit ReFiSold(sender, swapAmount, feeAmount);
        }
```


**Impact:** 
- Very small swaps may incur zero fees
- Potential for fee avoidance through micro-transactions
- Minor economic impact


**Proof of Concept:**



<details>
<summary>PoC</summary>


Add the following to `RebateFiHookTest.t.sol`

```js
function test_FeeCalculationPrecisionLoss() public {
    uint256 smallSwapAmount = 100; // 100 wei
    uint256 expectedFee = (smallSwapAmount * 3000) / 100000; // = 3 wei
    
    uint256 tinySwapAmount = 1;
    uint256 tinyFee = (tinySwapAmount * 3000) / 100000; // = 0 due to integer division
    assertEq(tinyFee, 0); // Fee rounds down to 0
}

```

</details>

**Recommendation:** 

```diff
        if (isReFiBuy) {
            fee = buyFee;    
-            emit ReFiBought(sender, swapAmount);
+            uint256 feeAmount = (swapAmount * buyFee * SCALING_FACTOR) / 100000 / SCALING_FACTOR;
+            if (feeAmount == 0 && swapAmount > 0) feeAmount = MIN_FEE_AMOUNT;
+            emit ReFiBought(sender, swapAmount, feeAmount);
        } else {
            fee = sellFee;
-            uint256 feeAmount = (swapAmount * sellFee) / 100000;
-            emit ReFiSold(sender, swapAmount, feeAmount);
+            uint256 feeAmount = (swapAmount * sellFee * SCALING_FACTOR) / 100000 / SCALING_FACTOR;
+            if (feeAmount == 0 && swapAmount > 0) feeAmount = MIN_FEE_AMOUNT;
+            emit ReFiSold(sender, swapAmount, feeAmount);
        }
```
- Consider minimum swap amounts
- Use scaled fee calculations for better precision
- Accept as known limitation of integer math

### [M-2] Front-running Fee Changes


**Description:** 
Fee changes in the `ChangeFee` function are immediately executable, creating MEV (Miner Extractable Value) opportunities where sophisticated traders can front-run fee change transactions to gain economic advantages.

```js
function ChangeFee(bool _isBuyFee, uint24 _buyFee, bool _isSellFee, uint24 _sellFee) external onlyOwner {
@>  if(_isBuyFee) buyFee = _buyFee;        // Immediate execution
@>  if(_isSellFee) sellFee = _sellFee;     // No timelock or delay
}
```

**Impact:** 
Sophisticated traders front-run fee changes for profit which creates perception of unfair trading environment where users pay unexpectedly high fees without warning and fee changes create predictable MEV opportunities.


**Proof of Concept:**



<details>
<summary>PoC</summary>


Add the following to `RebateFiHookTest.t.sol`

```js
function test_FrontRunningFeeChanges() public {
    uint24 originalSellFee = rebateHook.sellFee();
    rebateHook.ChangeFee(false, 0, true, 5000); // Increase sell fee to 50%
    (uint24 buyFee, uint24 sellFee) = rebateHook.getFeeConfig();
    assertEq(sellFee, 5000);
}

```

</details>

**Recommendation:** 
- Implement timelocks for fee changes to prevent front-running.
- Implement graduated fee changes to reduce MEV impact
- Provide fee change notifications to users
- Consider governance mechanisms for major fee changes



# LOW

### [L-1] Missing Events for Critical State Changes
The contract fails to emit events when fee parameters are modified, making off-chain monitoring, analytics, and user notification impossible. This lack of transparency undermines trust and makes the protocol difficult to integrate with external systems.


**Description:** 

```js
function ChangeFee(bool _isBuyFee, uint24 _buyFee, bool _isSellFee, uint24 _sellFee) external onlyOwner {
    if(_isBuyFee) buyFee = _buyFee;    // No event emitted
    if(_isSellFee) sellFee = _sellFee; // No event emitted
}
```

**Impact:** 
- Difficult to track fee changes off-chain
- Reduced transparency for users
- Harder to monitor contract activity


**Proof of Concept:**



<details>
<summary>PoC</summary>


Add the following to `RebateFiHookTest.t.sol`

```js
function test_NoEventOnFeeChange() public {
    rebateHook.ChangeFee(true, 1000, true, 4000);
    (uint24 buyFee, uint24 sellFee) = rebateHook.getFeeConfig();
    assertEq(buyFee, 1000);
    assertEq(sellFee, 4000);
    // No events emitted to track these changes
}

```

</details>

**Recommendation:** 


```diff
+ event FeesChanged(uint24 buyFee, uint24 sellFee);

function ChangeFee(bool _isBuyFee, uint24 _buyFee, bool _isSellFee, uint24 _sellFee) external onlyOwner {
    if(_isBuyFee) buyFee = _buyFee;
    if(_isSellFee) sellFee = _sellFee;
+   emit FeesChanged(buyFee, sellFee);
}
```



### [L-2] Potential Reentrancy in Withdraw


**Description:** 
While the withdrawal function follows the checks-effects-interactions pattern and uses standard ERC20 transfers, it remains potentially vulnerable to reentrancy attacks if the token contract implements callback mechanisms or unusual transfer behavior.

```js
    function withdrawTokens(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).transfer(to, amount);
        emit TokensWithdrawn(to, token , amount);
    }
```

**Impact:** 
- Low risk with standard ERC20 implementations
- Potential issues with ERC777 or similar tokens




**Recommendation:** 


```diff
    function withdrawTokens(address token, address to, uint256 amount) external onlyOwner {
+   // Consider reentrancy guard for extra safety
        IERC20(token).transfer(to, amount);
        emit TokensWithdrawn(to, token , amount);
    }
```

### [L-3] Insufficient Edge Case Handling in Withdrawal Logic


**Description:** 
The `withdrawTokens` function lacks comprehensive validation for edge cases, potentially leading to unnecessary gas costs, confusing event emissions, and integration issues with non-standard token behaviors.

```js
function withdrawTokens(address token, address to, uint256 amount) external onlyOwner {
@>  IERC20(token).transfer(to, amount); // Minimal validation
    emit TokensWithdrawn(to, token, amount);
}
```

**Impact:** 
Zero-amount withdrawals waste gas;
Unnecessary event emissions for zero-value operations;
Self-withdrawals create misleading event parameters;
May fail silently if token doesn't implement ERC20 properly.

**Proof of Concept:**



<details>
<summary>PoC</summary>


Add the following to `RebateFiHookTest.t.sol`

```js
function test_WithdrawZeroAmount() public {
    reFiToken.mint(address(rebateHook), 100 ether);
    rebateHook.withdrawTokens(address(reFiToken), address(this), 0);
    assertEq(reFiToken.balanceOf(address(rebateHook)), 100 ether);
}

function test_WithdrawMoreThanBalance() public {
    reFiToken.mint(address(rebateHook), 100 ether);
    vm.expectRevert(); // ERC20 transfer reverts on insufficient balance
    rebateHook.withdrawTokens(address(reFiToken), address(this), 200 ether);
}

```

</details>

**Recommendation:** 

```diff
    function withdrawTokens(address token, address to, uint256 amount) external onlyOwner {
+       require(amount > 0, "Cannot withdraw zero amount");
        IERC20(token).transfer(to, amount);
        emit TokensWithdrawn(to, token , amount);
    }
```

- Add maximum withdrawal limits to prevent accidental large transfers
- Implement withdrawal batching for multiple tokens
- Consider adding emergency withdrawal patterns with multisig requirements
- Add token blacklisting for problematic tokens



