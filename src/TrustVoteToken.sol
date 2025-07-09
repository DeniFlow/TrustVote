// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.30;

import {ERC20} from "node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "node_modules/@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "node_modules/@openzeppelin/contracts/access/Ownable.sol";

contract TrustVoteToken is ERC20, Ownable, ERC20Permit {
    constructor(address recipient, address initialOwner)
        ERC20("TrustVoteToken", "TVT")
        Ownable(initialOwner)
        ERC20Permit("TrustVoteToken")
    {
        _mint(recipient, 1000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
