// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./BaseToken.sol";
import "../strategies/StrategyBase.sol";

import "../interfaces/synth/ISYXSwap.sol";

contract SingleSCToken is BaseToken {
    address public strategy;
    address public uniRouterAddress;//SYXSwap
    address public rewardEscrow;
    address public rewardToken;//SYX

    struct RewardTokenInfo {
        uint256 accTokenPerShare;
        uint256 lastRewardBalance;
        uint256 lastRewardBlock;
    }
    struct UserInfo {
        int256 rewardDebt;
        uint256 amount;
    }
    RewardTokenInfo public rewardTokenInfo;
    mapping (address => UserInfo) public userInfos;

    function __SingleSCToken_init(
        address admin,
        string memory name_,
        string memory symbol_,
        address _token,
        address _strategy,
        address _priceGetter,
        address _uniRouterAddress,
        address _rewardToken,
        address _rewardEscrow
    ) public initializer {
        __ERC20_init(name_, symbol_);
        __ReentrancyGuard_init();
        token = _token;
        strategy = _strategy;
        govAddress = admin;
        isBNB = token == address(0);
        priceGetter = IPrices(_priceGetter);
        uniRouterAddress = _uniRouterAddress;
        rewardEscrow = _rewardEscrow;
        rewardToken = _rewardToken;
        if(!isBNB){
            approveToken();
        } 
    }

    function setPriceGetter(address _priceGetter) external {
        require(msg.sender == govAddress, "!gov");
        priceGetter = IPrices(_priceGetter);
    }

    function updateRewardTokenInfo() public {
        if (block.number <= rewardTokenInfo.lastRewardBlock) {
            return;
        }

        uint256 tokenBalance =
            getBalance().add(StrategyBase(strategy).calcIncome());
        uint256 lastRewardBalance = rewardTokenInfo.lastRewardBalance;
        rewardTokenInfo.lastRewardBlock = block.number;
        if (tokenBalance > lastRewardBalance) {
            uint256 income = tokenBalance.sub(lastRewardBalance);
            if (totalSupply() == 0) {
                rewardTokenInfo.accTokenPerShare = 0;
            } else {
                rewardTokenInfo.accTokenPerShare = rewardTokenInfo.accTokenPerShare.add(
                    income.mul(1e18).div(totalSupply())
                );
            }
        }
        rewardTokenInfo.lastRewardBalance = tokenBalance;
    }

    function depositBNB(uint256 _minShares) external payable override {
        require(!depositPaused, "deposit paused");
        require(isBNB, "not bnb");
        require(msg.value != 0, "deposit must be greater than 0");
        _deposit(msg.value, _minShares);
    }

    function deposit(uint256 _amount, uint256 _minShares) external override {
        require(!depositPaused, "deposit paused");
        require(_amount != 0, "deposit must be greater than 0");
        IERC20Upgradeable(token).safeTransferFrom(msg.sender, address(this), _amount);
        _deposit(_amount, _minShares);
    }

    function _deposit(uint256 _amount, uint256 _minShares) internal nonReentrant {
        updateRewardTokenInfo();
        uint256 _pool = calcPoolValueInToken();
        uint256 sharesToMint;
        if(isBNB){
            sharesToMint = StrategyBase(strategy).deposit{value: msg.value}(_amount);
        }else{
            sharesToMint = StrategyBase(strategy).deposit(_amount);
        }
        if (totalSupply() != 0 && _pool != 0) {
            sharesToMint = (sharesToMint.mul(totalSupply())).div(_pool);
        }
        require(sharesToMint >= _minShares, "did not meet minimum shares requested");
        int256 pending = int256(userInfos[msg.sender].amount.mul(rewardTokenInfo.accTokenPerShare).div(1e18)) - userInfos[msg.sender].rewardDebt;

        userInfos[msg.sender].amount = userInfos[msg.sender].amount.add(sharesToMint);

        int256 newRewardDebt = int256(userInfos[msg.sender].amount.mul(rewardTokenInfo.accTokenPerShare).div(1e18));
        userInfos[msg.sender].rewardDebt = newRewardDebt-pending;
        
        _mint(msg.sender, sharesToMint);
    }

    function withdraw(uint256 _shares, uint256 _minAmount) external override {
        uint256 r = _withdraw(_shares, _minAmount);
        IERC20Upgradeable(token).safeTransfer(msg.sender, r);
    }

    function withdrawBNB(uint256 _shares, uint256 _minAmount) external override {
        require(isBNB, "not bnb");
        uint256 r = _withdraw(_shares, _minAmount);
        uint256 transferAmount = r;
        if(address(this).balance < r){
            transferAmount = address(this).balance;
        }
        msg.sender.transfer(transferAmount);
    }

    function _withdraw(uint256 _shares, uint256 _minAmount) internal nonReentrant returns (uint256) {
        require(!withdrawPaused, "withdraw paused");
        require(_shares != 0, "shares must be greater than 0");

        uint256 ibalance = balanceOf(msg.sender);
        require(_shares <= ibalance, "insufficient balance");

        updateRewardTokenInfo();

        uint256 r = sharesToAmount(_shares);
        _burn(msg.sender, _shares);
        int256 pending = int256(userInfos[msg.sender].amount.mul(rewardTokenInfo.accTokenPerShare).div(1e18)) - userInfos[msg.sender].rewardDebt;

        userInfos[msg.sender].amount = userInfos[msg.sender].amount.sub(_shares);
        int256 newRewardDebt = int256(userInfos[msg.sender].amount.mul(rewardTokenInfo.accTokenPerShare).div(1e18));
        userInfos[msg.sender].rewardDebt = newRewardDebt - pending;

        uint256 b = getBalance();
        if (b < r) {
            StrategyBase(strategy).withdraw(r.sub(b));
            r = getBalance();
        }

        require(r >= _minAmount, "did not meet minimum amount requested");

        return r;
    }

    function earn(address user) external override returns(uint256) {
        updateRewardTokenInfo();
        UserInfo memory userInfo = userInfos[msg.sender];
        uint256 accTokenPerShare = rewardTokenInfo.accTokenPerShare;
        int256 pending = int256(userInfo.amount.mul(accTokenPerShare).div(1e18)) - userInfo.rewardDebt;
        int256 newRewardDebt = int256(userInfo.amount.mul(accTokenPerShare).div(1e18));
        userInfos[msg.sender].rewardDebt = newRewardDebt;
        if (pending > 0) {
            uint256 sellAmount;
            if(uint256(pending) > getBalance()){
                uint256 earnAmount = StrategyBase(strategy).earn(uint256(pending).sub(getBalance()));
                sellAmount = getBalance();
            }else{
                sellAmount = uint256(pending);
            }

            uint256 rewardBefore = IERC20Upgradeable(rewardToken).balanceOf(address(this));
            if(isBNB){
                ISYXSwap(uniRouterAddress).buySyx{value:sellAmount}(
                    token,
                    sellAmount
                );
            }else{
                ISYXSwap(uniRouterAddress).buySyx(
                    token,
                    sellAmount
                );
            }
            uint256 rewardEnd = IERC20Upgradeable(rewardToken).balanceOf(address(this));

            uint256 rewardAmount = rewardEnd.sub(rewardBefore);
            IERC20Upgradeable(rewardToken).safeApprove(rewardEscrow, 0);
            IERC20Upgradeable(rewardToken).safeApprove(rewardEscrow, rewardAmount);
            IRewardEscrow(rewardEscrow).deposit(user, rewardAmount);
            return rewardAmount;
        } 

        return 0;
    }

    function approveToken() public {
        IERC20Upgradeable(token).safeApprove(strategy, 0);
        IERC20Upgradeable(token).safeApprove(strategy, uint256(-1));
        IERC20Upgradeable(token).safeApprove(uniRouterAddress, 0);
        IERC20Upgradeable(token).safeApprove(uniRouterAddress, uint256(-1));
    }

    function getBalance() public view override returns (uint256) {
        if(isBNB){
            return address(this).balance.sub(msg.value);
        }else{
            return IERC20Upgradeable(token).balanceOf(address(this));
        }
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
        if (isBNB) {
            return multiplyDecimal(getPricePerFullShare(), priceGetter.getPrice(stringToBytes32("BNB")));
        } else {
            return
                multiplyDecimal(
                    getPricePerFullShare(),
                    priceGetter.getPrice(stringToBytes32(ERC20Upgradeable(token).symbol()))
                );
        }
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

    function emergencyWithdraw(
        address _token,
        uint256 _amount,
        address _to
    ) public {
        require(msg.sender == govAddress, "!gov");
        require(_token != address(this), "!safe");
        if (_token == address(0)) {
            require(address(this).balance >= _amount, "amount greater than holding");
            payable(_to).transfer(_amount);
        } else if (_token == token) {
            require(getBalance() >= _amount, "amount greater than holding");
            IERC20Upgradeable(_token).safeTransfer(_to, _amount);
        }
        
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
