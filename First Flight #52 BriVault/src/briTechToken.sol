// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BriTechToken is ERC20, Ownable {
    constructor() ERC20("BriTechLabs", "BTT") Ownable(msg.sender) {}

    function mint() public onlyOwner {
        _mint(owner(), 10_000_000 * 1e18);
    }
}
