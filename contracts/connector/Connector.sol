// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/synth/ICollateral.sol";
import "../tokens/BaseToken.sol";

contract Connector {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public owner;
    ICollateral public icollateral;
    IERC20 public syUSD;

    modifier onlyOwner() {
        require(isOwner(), "caller is not the owner");
        _;
    }

    constructor(
        address _owner,
        ICollateral _collateral,
        address _syUSD
    ) public {
        require(_owner != address(0), "ERR_OWNER_INVALID");
        require(address(_collateral) != address(0), "ERR_COLLATERAL_INVALID");
        require(address(_syUSD) != address(0), "ERR_USD_INVALID");
        owner = _owner;
        icollateral = _collateral;
        syUSD = IERC20(_syUSD);
    }

    receive() external payable {}

    function emergencyWithdraw(IERC20 token) external onlyOwner {
        if (address(token) == address(0)) {
            msg.sender.transfer(address(this).balance);
        } else {
            token.safeTransfer(owner, token.balanceOf(address(this)));
        }
    }

    function isOwner() public view returns (bool) {
        return msg.sender == owner;
    }

    function getUserCollateral(BaseToken scToken) external view returns (uint256) {
        return
            icollateral
                .getUserCollateral(address(this), stringToBytes32(scToken.symbol()))
                .mul(scToken.getPricePerFullShare())
                .div(1e18);
    }

    function getUserTotalCollateralInUsd() external view returns (uint256) {
        return icollateral.getUserTotalCollateralInUsd(address(this));
    }

    function getUserMinCollateralRatio() external view returns (uint256) {
        return icollateral.getUserMinCollateralRatio(address(this));
    }

    function hasMinCRatio() external view returns (bool) {
        return icollateral.hasMinCRatio(address(this));
    }

    function maxRedeemableInUsd() external view returns (uint256) {
        return icollateral.maxRedeemableInUsd(address(this));
    }

    function maxRedeemable(BaseToken scToken) external view returns (uint256) {
        return
            icollateral
                .maxRedeemable(address(this), stringToBytes32(scToken.symbol()))
                .mul(scToken.getPricePerFullShare())
                .div(1e18);
    }

    function stakeAndBuild(
        BaseToken scToken,
        uint256 stakeAmount,
        uint256 mintAmount
    ) external payable onlyOwner {
        _depositToSCToken(scToken, stakeAmount);

        icollateral.stakeAndBuild(stringToBytes32(scToken.symbol()), scToken.balanceOf(address(this)), mintAmount);
        syUSD.safeTransfer(owner, syUSD.balanceOf(address(this)));
    }

    function stakeAndBuildMax(BaseToken scToken, uint256 stakeAmount) external payable onlyOwner {
        _depositToSCToken(scToken, stakeAmount);
        icollateral.stakeAndBuildMax(stringToBytes32(scToken.symbol()), scToken.balanceOf(address(this)));
        syUSD.safeTransfer(owner, syUSD.balanceOf(address(this)));
    }

    function collateral(BaseToken scToken, uint256 amount) external payable onlyOwner returns (bool) {
        require(amount > 0, "amount must large than zero");
        _depositToSCToken(scToken, amount);
        return icollateral.collateral(stringToBytes32(scToken.symbol()), scToken.balanceOf(address(this)));
    }

    function earn(BaseToken scToken) external {
        scToken.earn(owner);
    }

    function _depositToSCToken(BaseToken scToken, uint256 stakeAmount) private {
        if (stakeAmount > 0) {
            address scTokenAddress = address(scToken);
            if (scToken.isBNB()) {
                require(msg.value >= stakeAmount, "amount not enough");
                scToken.depositBNB{value: msg.value}(0);
            } else {
                IERC20 token = IERC20(scToken.token());
                token.safeTransferFrom(msg.sender, address(this), stakeAmount);
                if (token.allowance(address(this), scTokenAddress) < stakeAmount) {
                    token.safeApprove(scTokenAddress, 0);
                    token.safeApprove(scTokenAddress, uint256(-1));
                }
                scToken.deposit(stakeAmount, 0);
            }
            if (
                IERC20(scTokenAddress).allowance(address(this), address(icollateral)) < scToken.balanceOf(address(this))
            ) {
                IERC20(scTokenAddress).safeApprove(address(icollateral), 0);
                IERC20(scTokenAddress).safeApprove(address(icollateral), uint256(-1));
            }
        }
    }

    function burnAndUnstake(
        BaseToken scToken,
        uint256 burnAmount,
        uint256 unstakeAmount
    ) external onlyOwner {
        syUSD.safeTransferFrom(msg.sender, address(this), burnAmount);
        if (syUSD.allowance(address(this), address(icollateral)) < burnAmount) {
            syUSD.safeApprove(address(icollateral), 0);
            syUSD.safeApprove(address(icollateral), uint256(-1));
        }
        uint256 unstakeSCTokenAmount = unstakeAmount.mul(1e18).div(scToken.getPricePerFullShare());
        icollateral.burnAndUnstake(burnAmount, stringToBytes32(scToken.symbol()), unstakeSCTokenAmount);
        _withdrawFromSCToken(scToken);

        // The overcharged usd is returned to the user
        syUSD.safeTransfer(owner, syUSD.balanceOf(address(this)));
    }

    function burnAndUnstakeMax(BaseToken scToken, uint256 burnAmount) external onlyOwner {
        syUSD.safeTransferFrom(msg.sender, address(this), burnAmount);
        if (syUSD.allowance(address(this), address(icollateral)) < burnAmount) {
            syUSD.safeApprove(address(icollateral), 0);
            syUSD.safeApprove(address(icollateral), uint256(-1));
        }
        icollateral.burnAndUnstakeMax(burnAmount, stringToBytes32(scToken.symbol()));
        _withdrawFromSCToken(scToken);

        // The overcharged usd is returned to the user
        syUSD.safeTransfer(owner, syUSD.balanceOf(address(this)));
    }

    function redeemMax(BaseToken scToken) external onlyOwner {
        icollateral.redeemMax(stringToBytes32(scToken.symbol()));
        _withdrawFromSCToken(scToken);
    }

    function redeem(BaseToken scToken, uint256 amount) external onlyOwner {
        uint256 unstakeSCTokenAmount = amount.mul(1e18).div(scToken.getPricePerFullShare());
        icollateral.redeem(stringToBytes32(scToken.symbol()), unstakeSCTokenAmount);
        _withdrawFromSCToken(scToken);
    }

    function _withdrawFromSCToken(BaseToken scToken) private {
        if (scToken.balanceOf(address(this)) > 0) {
            if (scToken.isBNB()) {
                scToken.withdrawBNB(scToken.balanceOf(address(this)), 0);
                msg.sender.transfer(address(this).balance);
            } else {
                scToken.withdraw(scToken.balanceOf(address(this)), 0);
                IERC20 token = IERC20(scToken.token());
                token.safeTransfer(msg.sender, token.balanceOf(address(this)));
            }
        }
    }

    function stringToBytes32(string memory source) public pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }
}
