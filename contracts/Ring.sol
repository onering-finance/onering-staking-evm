pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Ring is ERC20 {
    constructor() ERC20("OneRing","RING"){
        _mint(msg.sender, 1000000000000e18);
    }
}