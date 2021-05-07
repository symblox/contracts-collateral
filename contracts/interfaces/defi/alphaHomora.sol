// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface Bank {
    function totalBNB() external view returns (uint256 amount);

    function deposit() external payable;

    function withdraw(uint256 share) external;
}

interface ALPHAToken is IERC20 {}
