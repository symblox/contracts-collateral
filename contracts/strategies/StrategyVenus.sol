// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./StrategyBase.sol";

import "../interfaces/defi/venus.sol";
import "../interfaces/defi/pancake.sol";

contract StrategyVenus is StrategyBase {
    bool public wantIsWBNB;
    address public wantAddress;//stake token
    address public vTokenAddress;
    address public venusComptroller;
    address public xvs;//venus address
    uint256 public supplyBal;//token balance in venus
    address public routerAddress;
    address[] public xvsToWantPaths;
    uint256 public totalPrincipal;
    uint256 public harvesterReward;
    uint256 public FEE_DENOMINATOR;

    function __StrategyVenus_init(address admin, address _wantAddress, address _vTokenAddress, address _xvs, address _venusComptroller, address _routerAddress, address[] memory _xvsToWantPaths) public initializer {
        govAddress = admin;
        wantAddress = _wantAddress;
        wantIsWBNB = _wantAddress == address(0);
        vTokenAddress = _vTokenAddress;
        xvs = _xvs;
        venusComptroller = _venusComptroller;
        routerAddress = _routerAddress;
        xvsToWantPaths = _xvsToWantPaths;
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        harvesterReward = 30;
        FEE_DENOMINATOR = 10000;
    }

    function setPath(address[] memory _xvsToWantPaths) external {
        require(msg.sender == govAddress, "Not authorized");
        xvsToWantPaths = _xvsToWantPaths;
    }

    function setGov(address _govAddress) public override {
        require(msg.sender == govAddress, "Not authorized");
        govAddress = _govAddress;
    }

    function deposit(uint256 _wantAmt) public payable override nonReentrant whenNotPaused returns (uint256) {
        updateBalance();
        uint256 prevBalance = wantLockedTotal();
        
        if (wantIsWBNB) {
            require(_wantAmt == msg.value, "deposit amount error");
            prevBalance = prevBalance.sub(msg.value);
            IVBNB(vTokenAddress).mint{value: _wantAmt}();
        } else {
            IERC20Upgradeable(wantAddress).safeTransferFrom(address(msg.sender), address(this), _wantAmt);
            IERC20Upgradeable(wantAddress).safeApprove(vTokenAddress, 0);
            IERC20Upgradeable(wantAddress).safeApprove(vTokenAddress, _wantAmt);
            require(IVToken(vTokenAddress).mint(_wantAmt) == 0, "mint error");
        }

        updateBalance();
        uint256 diffBalance = wantLockedTotal().sub(prevBalance);
        totalPrincipal = totalPrincipal.add(diffBalance);
        return diffBalance;
    }

    function withdraw(uint256 _wantAmt) external override onlyOwner nonReentrant whenNotPaused returns (uint256) {
        updateBalance();
        uint256 wantBal = wantLockedLocal();
        if (wantBal < _wantAmt) {
            require(IVToken(vTokenAddress).redeemUnderlying(_wantAmt.sub(wantBal)) == 0, "redeemUnderlying error");
            updateBalance();
            wantBal = wantLockedLocal();
        }

        if (wantBal < _wantAmt) {
            _wantAmt = wantBal;
        }

        if (wantIsWBNB) {
            if(address(this).balance < _wantAmt){
                _wantAmt = address(this).balance;
            }
            
            payable(owner()).transfer(_wantAmt);
        }else{
            if(IERC20Upgradeable(wantAddress).balanceOf(address(this)) < _wantAmt){
                _wantAmt = IERC20Upgradeable(wantAddress).balanceOf(address(this));
            }

            IERC20Upgradeable(wantAddress).safeTransfer(owner(), _wantAmt);
        }

        totalPrincipal = totalPrincipal.sub(_wantAmt);
        return _wantAmt;
    }

    function _claimXvs() internal {
      IVenusComptroller(venusComptroller).claimVenus(address(this));
    }

    function _convertRewardsToWant(uint256 amount) internal {
        if (IERC20Upgradeable(xvs).allowance(address(this), routerAddress) < amount) {
            IERC20Upgradeable(xvs).safeApprove(routerAddress, 0);
            IERC20Upgradeable(xvs).safeApprove(routerAddress, amount);
        }

        if(wantIsWBNB){
            IPancakeRouter02(routerAddress).swapExactTokensForETH(
                amount,
                0,
                xvsToWantPaths,
                address(this),
                now.add(600)
            );
        }else{
            IPancakeRouter02(routerAddress).swapExactTokensForTokens(
                amount,
                0,
                xvsToWantPaths,
                address(this),
                now.add(600)
            );
        }    
    }

    //claim xvs income to buy wanttoken and then deposit to venus
    function harvest() public returns (uint256 harvesterRewarded) {
        //Called by the transaction sender, rewarded to the transaction sender
        require(msg.sender == tx.origin, "not eoa");
        //claim xvs income
        _claimXvs();
        uint256 earnedAmt = IERC20Upgradeable(xvs).balanceOf(address(this));
        uint256 _harvesterReward;
        if (earnedAmt > 0) {
            //buy wanttoken
            _convertRewardsToWant(earnedAmt);
            if (wantIsWBNB) {
                uint256 bal = address(this).balance;
                if(bal > 0){
                    //Reward transaction initiator
                    _harvesterReward = bal.mul(harvesterReward).div(FEE_DENOMINATOR);
                    msg.sender.transfer(_harvesterReward);
                    //deposit to venus
                    IVBNB(vTokenAddress).mint{value: bal.sub(_harvesterReward)}();
                }
            } else {
                uint256 bal = IERC20Upgradeable(wantAddress).balanceOf(address(this));
                if( bal > 0 ){
                    //Reward transaction initiator
                    _harvesterReward = bal.mul(harvesterReward).div(FEE_DENOMINATOR);
                    IERC20Upgradeable(wantAddress).safeTransfer(msg.sender, _harvesterReward);
                    //deposit to venus
                    IERC20Upgradeable(wantAddress).safeApprove(vTokenAddress, 0);
                    IERC20Upgradeable(wantAddress).safeApprove(vTokenAddress, bal.sub(_harvesterReward));
                    require(IVToken(vTokenAddress).mint(bal.sub(_harvesterReward)) == 0, "mint error");
                }
            }
        }
        updateBalance();
        return _harvesterReward;
    }

    //withdraw stake token income
    function earn(uint256 amount) external override onlyOwner nonReentrant whenNotPaused returns(uint256){
        uint256 totalIncome = calcIncome();
        if(totalIncome > 0){
            if(totalIncome < amount){
                amount = totalIncome;
            }

            require(IVToken(vTokenAddress).redeemUnderlying(amount.sub(wantLockedLocal())) == 0, "redeemUnderlying error");

            if (wantIsWBNB) {     
                payable(owner()).transfer(amount);
            }else{
                IERC20Upgradeable(wantAddress).safeTransfer(owner(), amount);
            }

            updateBalance();
            return amount;
        }

        return 0;
    }

    //calc total income
    function calcIncome() public override returns (uint256) {
        updateBalance();
        uint256 totalBal = wantLockedTotal();
        uint256 principal = wantLockedPrincipal();
        if(totalBal > principal){
            return totalBal.sub(principal);
        }else{
            return 0;
        }     
    }

    function pause() public {
        require(msg.sender == govAddress, "Not authorized");
        _pause();
    }

    function unpause() external {
        require(msg.sender == govAddress, "Not authorized");
        _unpause();
    }

    //update token balance in venus
    function updateBalance() public {
        supplyBal = IVToken(vTokenAddress).balanceOfUnderlying(address(this));
    }

    // principal balance of want tokens in this contract + amount of tokens in defi, Does not include interest
    function wantLockedPrincipal() public view override returns (uint256) {
        return totalPrincipal;
    }

    // balance of want tokens in this contract + amount of tokens in defi
    function wantLockedTotal() public view override returns (uint256) {
        return wantLockedLocal().add(
            supplyBal
        );
    }

    // balance of want tokens in this contract
    function wantLockedLocal() public view override returns (uint256) {
        if (wantIsWBNB) {
            return address(this).balance;
        } else {
            return IERC20Upgradeable(wantAddress).balanceOf(address(this));
        }
    }

    function emergencyWithdraw(
        address _token,
        uint256 _amount,
        address _to
    ) public override {
        require(msg.sender == govAddress, "!gov");
        require(_token != wantAddress, "!safe");

        IERC20Upgradeable(_token).safeTransfer(_to, _amount);
    }

    receive() external payable {}
}
