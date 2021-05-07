// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockCollateral {
    IERC20 public usd;
    IERC20 public scToken;

    constructor(address _usd, address _scToken) public {
        usd = IERC20(_usd);
        scToken = IERC20(_scToken);
    }

    uint256 public userCollateral;
    uint256 public userTotalCollateralInUsd;
    uint256 public userMinCollateralRatio;
    uint256 public hasMinCRatio;
    uint256 public maxRedeemableInUsd;
    uint256 public maxRedeemable;
    uint256 public collateral_;

    function setUserCollateral(uint256 amount) external returns(uint256) {
        return userCollateral = amount;
    }

    function getUserCollateral(address user, bytes32 currency) external returns(uint256) {
        return userCollateral;
    }

    function setUserTotalCollateralInUsd(uint256 amount) external returns(uint256) {
        return userTotalCollateralInUsd = amount;
    }

    function getUserTotalCollateralInUsd(address user) external returns(uint256) {
        return userTotalCollateralInUsd;
    }

    function setUserMinCollateralRatio(uint256 amount) external returns(uint256) {
        return userTotalCollateralInUsd = amount;
    }

    function getUserMinCollateralRatio(address user) external returns(uint256) {
        return userMinCollateralRatio;
    }

    function setHasMinCRatio(uint256 amount) external returns(uint256) {
        return hasMinCRatio = amount;
    }

    function getHasMinCRatio(address user) external returns(uint256) {
        return hasMinCRatio;
    }

    function setMaxRedeemableInUsd(uint256 amount) external returns(uint256) {
        return maxRedeemableInUsd = amount;
    }

    function getMaxRedeemableInUsd(address user) external returns(uint256) {
        return maxRedeemableInUsd;
    }

    function setMaxRedeemable(uint256 amount) external returns(uint256) {
        return maxRedeemable = amount;
    }

    function getMaxRedeemable(address token, bytes32 currency) external returns(uint256) {
        return maxRedeemable;
    }

    function stakeAndBuild(
        bytes32 stakeCurrency,
        uint256 stakeAmount,
        uint256 mintAmount
    ) external {
        scToken.transferFrom(msg.sender, address(this), stakeAmount);
        usd.transfer(msg.sender, mintAmount);
    }

    function stakeAndBuildMax(bytes32 stakeCurrency, uint256 stakeAmount) external {
        scToken.transferFrom(msg.sender, address(this), stakeAmount);
        usd.transfer(msg.sender, stakeAmount);
    }
 
    function burnAndUnstake(
        uint256 burnAmount,
        bytes32 stakeCurrency,
        uint256 unstakeAmount
    ) external {
       usd.transferFrom(msg.sender, address(this), burnAmount);
       scToken.transfer(msg.sender, unstakeAmount);
    }

    function burnAndUnstakeMax(
        uint256 burnAmount,
        bytes32 stakeCurrency
    ) external {
       usd.transferFrom(msg.sender, address(this), burnAmount);
       scToken.transfer(msg.sender, scToken.balanceOf(address(this)));
    }

    function setCollateral(uint256 amount) public {
        collateral_ = amount;
    }

    function collateral(bytes32 currency, uint256 amount) external returns (uint256) {
        scToken.transferFrom(msg.sender, address(this), amount);
        return collateral_;
    }

    function redeemMax(bytes32 currency) external {
        scToken.transfer(msg.sender, scToken.balanceOf(address(this)));
    }

    function redeem(bytes32 currency, uint256 amount) external returns (bool) {
        scToken.transfer(msg.sender, amount);
        return true;
    }
}





                
