// SPDX-License-Identifier: MIT
pragma solidity >=0.4.24;

interface IRewardEscrow {
    function deposit(address user, uint256 amount) external; 
}
