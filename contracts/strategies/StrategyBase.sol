// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

abstract contract StrategyBase is OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    address public govAddress;

    uint256 public lastEarnBlock;

    address public buyBackAddress;

    // balance of want tokens in this contract + amount of tokens in defi
    function wantLockedTotal() public view virtual returns (uint256);

    // balance of want tokens in this contract
    function wantLockedLocal() public view virtual returns (uint256);

    // principal balance of want tokens in this contract + amount of tokens in defi, Does not include interest
    function wantLockedPrincipal() public view virtual returns (uint256);

    // deposit want tokens to defi
    function deposit(uint256 _wantAmt) external virtual returns (uint256);

    // withdraw want tokens from defi
    function withdraw(uint256 _wantAmt) external virtual returns (uint256);

    function emergencyWithdraw(
        address _token,
        uint256 _amount,
        address _to
    ) external virtual;

    function setBuyBackAddress(address _buyBackAddress) external virtual;

    function setGov(address _govAddress) external virtual;
}
