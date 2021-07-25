//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.2;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract dummyToken is ERC20 {
    constructor(uint256 supply) ERC20("DM", "Dummy") {
        _mint(msg.sender, supply);
    }
}
