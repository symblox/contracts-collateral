// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

contract MockPrice {
    constructor() public {}

    mapping(bytes32 => uint256) public prices;

    function getPrice(bytes32 currency) external view returns(uint256) {
        return prices[currency];
    }

    function setPrice(bytes32 currency, uint256 price) external {
        prices[currency] = price;
    }
}
