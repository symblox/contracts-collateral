// SPDX-License-Identifier: MIT
pragma solidity >=0.4.24;

interface ISYXSwap {
    /**
     * @dev get buy token address e.g syx
     */
    function targetToken() external view returns (address);

    /**
     * @dev buy syx
     *
     * @param token sell token address
     * @param amount sell amount
     */
    function buySyx(address token, uint256 amount) external payable;
}
