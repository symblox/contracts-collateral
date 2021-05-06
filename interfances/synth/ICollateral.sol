// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface ICollateral {
    function issuer() external view returns (address);

    function hasMinCRatio(address _user) external view returns (bool);

    function getUserCollateral(address _user, bytes32 currency) external view returns (uint256);

    function getUserTotalCollateralInUsd(address _user) external view returns (uint256 rTotal);

    function maxRedeemableInUsd(address _user) external view returns (uint256);

    function maxRedeemable(address _user, bytes32 currency) external view returns (uint256);

    function getUserMinCollateralRatio(address _user) external view returns (uint256);

    function stakeAndBuild(
        bytes32 stakeCurrency,
        uint256 stakeAmount,
        uint256 mintAmount
    ) external payable;

    function stakeAndBuildMax(bytes32 stakeCurrency, uint256 stakeAmount) external payable;

    function burnAndUnstake(
        uint256 burnAmount,
        bytes32 unstakeCurrency,
        uint256 unstakeAmount
    ) external;

    function burnAndUnstakeMax(uint256 burnAmount, bytes32 unstakeCurrency) external;

    function collateral(bytes32 currency, uint256 amount) external payable returns (bool);

    function redeemMax(bytes32 currency) external;

    function redeem(bytes32 currency, uint256 amount) external;
}
