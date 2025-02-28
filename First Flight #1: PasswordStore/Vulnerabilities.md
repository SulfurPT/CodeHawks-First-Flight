## [H-1] Variable password is visable to anyone on-chain

### **Description:**
All data store on-chain is visible to anyone and it can be read directly from the blockchain.
The `PasswordStore::s_password` variable is intended to be a private variable and only accessed through the `PasswordStore::getPassword` function, which is intended to be only called by the owner of the contract, but, it is visible to everyone on-chain.

### **Impact:**
Anyone can read the private password, severly breaking the functionality of the protocol.

### **Proof of Concept:**
Above are the steps, to create the PoC:

<details>
<summary>Steps</summary>

Create a locally running chain
```bash
make anvil
```

Deploy the contract to the chain
```
make deploy
```

Run the storage tool on the storage slot for `PasswordStore::s_password`
```
cast storage <ADDRESS_HERE> 1 --rpc-url http://LocalAnvilIP:Port
```

You should get the output:
```
0x6d7950617373776f726400000000000000000000000000000000000000000014
```

You can then parse that hex to a string with:
```
cast parse-bytes32-string 0x6d7950617373776f726400000000000000000000000000000000000000000014
```

And get an output of the password:
```
myPassword
```
</details>

### **Recommended Mitigation:**
Due to this, the overall architecture of the contract should be rethought. One could encrypt the password off-chain, and then store the encrypted password on-chain. This would require the user to remember another password off-chain to decrypt the stored password. However, you're also likely want to remove the view function as you wouldn't want the user to accidentally send a transaction with this decryption key.




## [H-2] `PasswordStore::setPassword` has no access controls, meaning a non-owner could change the password

### **Description:**
The `PasswordStore::setPassword` function is set to be an `external` function, however the purpose of the smart contract and function's natspec indicate that `This function allows only the owner to set a new password.`

```javascript
    function setPassword(string memory newPassword) external {
->      // @Audit - There are no Access Controls.
        s_password = newPassword;
        emit SetNetPassword();
    }
```

### **Impact:**
Anyone can set/change the stored password, severely breaking the contract's intended functionality

### **Proof of Concept:**

Add the following to the PasswordStore.t.sol:

<details>
<summary>Code</summary>

```javascript
    function test_notOwner_can_set_password(address randomAddress) public {
        vm.assume(randomAddress != owner);
        vm.startPrank(randomAddress);
        string memory expectedPassword = "notOwnerPassword";
        passwordStore.setPassword(expectedPassword);

        vm.startPrank(owner);
        string memory actualPassword = passwordStore.getPassword();
        assertEq(actualPassword, expectedPassword);
    }
```
</details>

### **Recommended Mitigation:** 

Add an access control in the `PasswordStore::setPassword` function

<details>

```javascript
        if (msg.sender != s_owner) {
            revert PasswordStore__NotOwner();
```

</details>




## [I-1] The `PasswordStore::getPassword` natspec indicates a parameter that doesn't exist, causing the natspec to be incorrect.

### **Description:**

    /*
     * @notice This allows only the owner to retrieve the password.
    -> * @param newPassword The new password to set.
     */
    function getPassword() external view returns (string memory) 

The `PasswordStore::getPassword` function signature is `getPassword()` while the natspec says it should be `getPassword(string)`.

### **Impact:**

The natspec is incorrect

### **Proof of Concept:**

N/A

### **Recommended Mitigation:** 

Remove the incorrect natspec line

```diff
+ line you want to add (shown in green)
- line you want to remove (shown in red)
```