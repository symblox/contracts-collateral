// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./BaseToken.sol";
import "../strategies/StrategyBase.sol";

interface IWBNB is IERC20Upgradeable {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

contract SingleSCToken is BaseToken {
    address public strategy;

    function __SingleSCToken_init(
        address admin,
        string memory name_,
        string memory symbol_,
        address _token,
        address _wbnbAddress,
        address _strategy,
        address _priceGetter
    ) public initializer {
        __ERC20_init(name_, symbol_);
        __ReentrancyGuard_init();
        token = _token;
        strategy = _strategy;
        govAddress = admin;
        wbnbAddress = _wbnbAddress;
        isWbnb = token == _wbnbAddress;
        priceGetter = IPrices(_priceGetter);
        approveToken();
    }

    function depositBNB(uint256 _minShares) external payable override {
        require(!depositPaused, "deposit paused");
        require(isWbnb, "not bnb");
        require(msg.value != 0, "deposit must be greater than 0");
        _wrapBNB(msg.value);
        _deposit(msg.value, _minShares);
    }

    function deposit(uint256 _amount, uint256 _minShares) external override {
        require(!depositPaused, "deposit paused");
        require(_amount != 0, "deposit must be greater than 0");
        IERC20Upgradeable(token).safeTransferFrom(msg.sender, address(this), _amount);
        _deposit(_amount, _minShares);
    }

    function _deposit(uint256 _amount, uint256 _minShares) public nonReentrant {
        uint256 _pool = calcPoolValueInToken();
        uint256 sharesToMint = StrategyBase(strategy).deposit(_amount);
        if (totalSupply() != 0 && _pool != 0) {
            sharesToMint = (sharesToMint.mul(totalSupply())).div(_pool);
        }
        require(sharesToMint >= _minShares, "did not meet minimum shares requested");
        _mint(msg.sender, sharesToMint);
    }

    function withdraw(uint256 _shares, uint256 _minAmount) external override {
        uint256 r = _withdraw(_shares, _minAmount);
        IERC20Upgradeable(token).safeTransfer(msg.sender, r);
    }

    function withdrawBNB(uint256 _shares, uint256 _minAmount) external override {
        require(isWbnb, "not bnb");
        uint256 r = _withdraw(_shares, _minAmount);
        _unwrapBNB(r);
        msg.sender.transfer(r);
    }

    function _withdraw(uint256 _shares, uint256 _minAmount) internal nonReentrant returns (uint256) {
        require(!withdrawPaused, "withdraw paused");
        require(_shares != 0, "shares must be greater than 0");

        uint256 ibalance = balanceOf(msg.sender);
        require(_shares <= ibalance, "insufficient balance");

        uint256 r = sharesToAmount(_shares);
        _burn(msg.sender, _shares);

        uint256 b = getBalance();
        if (b < r) {
            // require(balanceStrategy() >= r.sub(b));
            StrategyBase(strategy).withdraw(r.sub(b));
            r = getBalance();
        }

        require(r >= _minAmount, "did not meet minimum amount requested");

        return r;
    }

    function approveToken() public {
        IERC20Upgradeable(token).safeApprove(strategy, 0);
        IERC20Upgradeable(token).safeApprove(strategy, uint256(-1));
    }

    function getBalance() public view override returns (uint256) {
        return IERC20Upgradeable(token).balanceOf(address(this));
    }

    function balanceStrategy() public view override returns (uint256) {
        return StrategyBase(strategy).wantLockedPrincipal();
    }

    function calcPoolValueInToken() public view override returns (uint256) {
        return balanceStrategy();
    }

    function getPricePerFullShare() public view override returns (uint256) {
        uint256 _pool = calcPoolValueInToken();
        if (totalSupply() == 0 || _pool == 0) {
            return 0;
        } else {
            return _pool.mul(uint256(10)**uint256(decimals())).div(totalSupply());
        }
    }

    //return scToken price in usd
    function getPrice() public view override returns (uint256) {
        return
            multiplyDecimal(
                getPricePerFullShare(),
                priceGetter.getPrice(stringToBytes32(ERC20Upgradeable(token).symbol()))
            );
    }

    function sharesToAmount(uint256 _shares) public view override returns (uint256) {
        uint256 _pool = calcPoolValueInToken();
        uint256 amount;
        if (totalSupply() == 0 || _pool == 0) {
            amount = _shares;
        } else {
            amount = _shares.mul(_pool).div(totalSupply());
        }
        return amount;
    }

    function amountToShares(uint256 _amount) public view override returns (uint256) {
        uint256 _pool = calcPoolValueInToken();
        uint256 shares;
        if (totalSupply() == 0 || _pool == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(totalSupply())).div(_pool);
        }
        return shares;
    }

    function _wrapBNB(uint256 _amount) internal {
        if (address(this).balance >= _amount) {
            IWBNB(wbnbAddress).deposit{value: _amount}();
        }
    }

    function _unwrapBNB(uint256 _amount) internal {
        uint256 wbnbBal = IERC20Upgradeable(wbnbAddress).balanceOf(address(this));
        if (wbnbBal >= _amount) {
            IWBNB(wbnbAddress).withdraw(_amount);
        }
    }

    function emergencyWithdraw(
        address _token,
        uint256 _amount,
        address _to
    ) public {
        require(msg.sender == govAddress, "!gov");
        require(_token != address(this), "!safe");
        if (_token == address(0)) {
            require(address(this).balance >= _amount, "amount greater than holding");
            _wrapBNB(_amount);
        } else if (_token == token) {
            require(getBalance() >= _amount, "amount greater than holding");
        }
        IERC20Upgradeable(_token).safeTransfer(_to, _amount);
    }

    function multiplyDecimal(uint256 x, uint256 y) internal pure returns (uint256) {
        return x.mul(y) / 1e18;
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

    receive() external payable {}
}
