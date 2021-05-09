// contracts/resolvtoken.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract ResolvToken is ERC20Burnable {
    constructor(uint256 initialSupply) ERC20("Resolv", "RSLV") {
        _mint(msg.sender, initialSupply);
    }
}