pragma solidity 0.6.12;

import "./StrategyBase.sol";

contract StrategyIdle is StrategyBase {
    address public wantAddress;

    function __StrategyIdle_init(address admin, address _wantAddress) public initializer {
        govAddress = admin;
        wantAddress = _wantAddress;
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
    }

    function deposit(uint256 _wantAmt) public override nonReentrant whenNotPaused returns (uint256) {
        IERC20Upgradeable(wantAddress).safeTransferFrom(address(msg.sender), address(this), _wantAmt);
        return _wantAmt;
    }

    function withdraw(uint256 _wantAmt) external override onlyOwner nonReentrant returns (uint256) {
        IERC20Upgradeable(wantAddress).safeTransfer(owner(), _wantAmt);
        return _wantAmt;
    }

    function pause() public {
        require(msg.sender == govAddress, "Not authorised");
        _pause();
    }

    function unpause() external {
        require(msg.sender == govAddress, "Not authorised");
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
        uint256 wantBal = IERC20Upgradeable(wantAddress).balanceOf(address(this));
        return wantBal;
    }

    function setGov(address _govAddress) public override {
        require(msg.sender == govAddress, "Not authorised");
        govAddress = _govAddress;
    }

    function setBuyBackAddress(address _buyBackAddress) external override onlyOwner {
        revert();
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
