pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "../interfaces/synth/IPrices.sol";

abstract contract BaseToken is ERC20Upgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    address public token;

    address public govAddress;

    IPrices public priceGetter;

    bool public constant isSCToken = true;

    bool public isWbnb;

    address public wbnbAddress;

    bool public depositPaused;

    bool public withdrawPaused;

    // deposit tokens to this minter and receive shares
    // tokens deposited this way remains in this contract until supplyStrategy is called
    function deposit(uint256 _amount, uint256 _minShares) external virtual;

    function depositBNB(uint256 _minShares) external payable virtual;

    function pauseDeposit() external virtual {
        require(!depositPaused, "deposit paused");
        require(msg.sender == govAddress, "Not authorized");
        depositPaused = true;
    }

    function unpauseDeposit() external virtual {
        require(depositPaused, "deposit not paused");
        require(msg.sender == govAddress, "Not authorized");
        depositPaused = false;
    }

    // return shares and receive tokens from strategy
    function withdraw(uint256 _shares, uint256 _minAmount) external virtual;

    function withdrawBNB(uint256 _shares, uint256 _minAmount) external virtual;

    function pauseWithdraw() external virtual {
        require(!withdrawPaused, "withdraw paused");
        require(msg.sender == govAddress, "Not authorized");
        withdrawPaused = true;
    }

    function unpauseWithdraw() external virtual {
        require(withdrawPaused, "withdraw not paused");
        require(msg.sender == govAddress, "Not authorized");
        withdrawPaused = false;
    }

    // balance of tokens that this contract is holding
    function balance() public view virtual returns (uint256);

    // total balance of tokens of a strategy
    function balanceStrategy() public view virtual returns (uint256);

    // sum of all tokens in this contract and in a strategy.
    function calcPoolValueInToken() public view virtual returns (uint256);

    // calculate the number of tokens you can receive per share
    function getPricePerFullShare() public view virtual returns (uint256);

    function getPrice() public view virtual returns (uint256);

    // convert shares to amount of tokens
    function sharesToAmount(uint256 _shares) public view virtual returns (uint256);

    // convert the amount of tokens to shares
    function amountToShares(uint256 _amount) public view virtual returns (uint256);

    function setGovAddress(address _govAddress) external virtual {
        require(msg.sender == govAddress, "Not authorized");
        govAddress = _govAddress;
    }
}
