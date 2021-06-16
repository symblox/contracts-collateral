// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./StrategyBase.sol";

contract StrategyIdle is StrategyBase {
    bool public wantIsWBNB;
    address public wantAddress;

    function __StrategyIdle_init(address admin, address _wantAddress) public initializer {
        govAddress = admin;
        wantAddress = _wantAddress;
        wantIsWBNB = _wantAddress == address(0);
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
    }

    function deposit(uint256 _wantAmt) public payable override nonReentrant whenNotPaused returns (uint256) {
        if (wantIsWBNB) {
            require(_wantAmt == msg.value, "deposit amount error");
        } else {
            IERC20Upgradeable(wantAddress).safeTransferFrom(address(msg.sender), address(this), _wantAmt);
        }
        return _wantAmt;
    }

    function withdraw(uint256 _wantAmt) external override onlyOwner nonReentrant whenNotPaused returns (uint256) {
        if (wantIsWBNB) {
            if(address(this).balance < _wantAmt){
                _wantAmt = address(this).balance;
            }
            
            payable(owner()).transfer(_wantAmt);
        } else {
            IERC20Upgradeable(wantAddress).safeTransfer(owner(), _wantAmt);
        }
        return _wantAmt;
    }

    function earn(uint256 amount) external override onlyOwner nonReentrant whenNotPaused returns(uint256) {}

    function calcIncome() public override returns (uint256) {}

    function pause() public {
        require(msg.sender == govAddress, "Not authorized");
        _pause();
    }

    function unpause() external {
        require(msg.sender == govAddress, "Not authorized");
        _unpause();
    }

    // principal balance of want tokens in this contract + amount of tokens in defi, Does not include interest
    function wantLockedPrincipal() public view override returns (uint256) {
        return wantLockedTotal();
    }

    // balance of want tokens in this contract + amount of tokens in defi
    function wantLockedTotal() public view override returns (uint256) {
        return wantLockedLocal();
    }

    // balance of want tokens in this contract
    function wantLockedLocal() public view override returns (uint256) {
        if (wantIsWBNB) {
            return address(this).balance;
        } else {
            return IERC20Upgradeable(wantAddress).balanceOf(address(this));
        }
    }

    function setGov(address _govAddress) public override {
        require(msg.sender == govAddress, "Not authorized");
        govAddress = _govAddress;
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
