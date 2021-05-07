import { ethers, waffle } from "hardhat";
import { expect, use } from "chai";
import { BigNumber, Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

use(waffle.solidity);

describe("StrategyIdle", function () {
  let deployer: SignerWithAddress,
    admin: SignerWithAddress,
    alice: SignerWithAddress;

  let strategyIdle: Contract, erc20: Contract;

  beforeEach(async function () {
    [deployer, admin, alice] = await ethers.getSigners();

    const ER20 = await ethers.getContractFactory("MockERC20");
    erc20 = await ER20.deploy("SYX", "SYX");

    const StrategyIdle = await ethers.getContractFactory("StrategyIdle");
    strategyIdle = await StrategyIdle.deploy();
    await strategyIdle
      .connect(deployer)
      .__StrategyIdle_init(admin.address, erc20.address);
  });

  it("set gov address and buy back address", async () => {
    let govAddress = await strategyIdle.govAddress();
    expect(govAddress).to.equal(admin.address);

    await strategyIdle.connect(admin).setGov(alice.address);

    govAddress = await strategyIdle.govAddress();
    expect(govAddress).to.equal(alice.address);

    //StrategyIdle no need to set BuyBackAddress, so revert to avoid wasting gas
    await expect(strategyIdle.setBuyBackAddress(alice.address)).to.reverted;
  });

  it("deposit and withdraw", async () => {
    const depositAmount = BigNumber.from(10).pow(18); //10e18 wei = 1

    await erc20.mint(alice.address, depositAmount);
    await erc20.connect(alice).approve(strategyIdle.address, depositAmount);

    await strategyIdle.connect(alice).deposit(depositAmount);

    let balance = await erc20.balanceOf(strategyIdle.address);
    expect(balance).to.equal(depositAmount);

    let totalBalance = await strategyIdle.wantLockedTotal();
    expect(totalBalance).to.equal(depositAmount);

    await expect(
      strategyIdle.connect(alice).withdraw(depositAmount)
    ).to.revertedWith("Ownable: caller is not the owner");

    await strategyIdle.withdraw(depositAmount);

    balance = await erc20.balanceOf(strategyIdle.address);
    expect(balance).to.equal(0);
  });

  it("if paused deposit and withdraw can not call", async () => {
    //only govAddress can call pause
    await expect(strategyIdle.connect(alice).pause()).to.revertedWith(
      "Not authorized"
    );
    await strategyIdle.connect(admin).pause();

    await erc20.mint(deployer.address, 1);
    await erc20.approve(strategyIdle.address, 1);

    //if paused,can not call deposit and withdraw
    await expect(strategyIdle.deposit(1)).to.revertedWith("Pausable: paused");
    await expect(strategyIdle.withdraw(1)).to.revertedWith("Pausable: paused");

    //only govAddress can call unpause
    await expect(strategyIdle.connect(alice).unpause()).to.revertedWith(
      "Not authorized"
    );
    await strategyIdle.connect(admin).unpause();

    //if unpause,can call deposit and withdraw
    await strategyIdle.deposit(1);
    await strategyIdle.withdraw(1);
  });

  it("emergency withdraw", async () => {
    const ER20 = await ethers.getContractFactory("MockERC20");
    const erc20Two = await ER20.deploy("DAI", "DAI");

    //strategyIdle starting balance is 0
    let balance = await erc20Two.balanceOf(strategyIdle.address);
    expect(balance).to.equal(0);

    const mintAmount = BigNumber.from(10).pow(18); //10e18 wei = 1
    await erc20Two.mint(strategyIdle.address, mintAmount);

    //mint 1 to strategyIdle
    balance = await erc20Two.balanceOf(strategyIdle.address);
    expect(balance).to.equal(mintAmount);

    //only govAddress can call emergencyWithdraw
    await expect(
      strategyIdle
        .connect(alice)
        .emergencyWithdraw(erc20Two.address, mintAmount, alice.address)
    ).to.revertedWith("!gov");

    //withdraw token can't be wantAddress
    const wantAddress = await strategyIdle.wantAddress();
    await expect(
      strategyIdle
        .connect(admin)
        .emergencyWithdraw(wantAddress, mintAmount, alice.address)
    ).to.revertedWith("!safe");

    await strategyIdle
      .connect(admin)
      .emergencyWithdraw(erc20Two.address, mintAmount, alice.address);

    //all balance has emergencyWithdraw to alice, so balance is 0
    balance = await erc20Two.balanceOf(strategyIdle.address);
    expect(balance).to.equal(0);

    //alice balance is 1
    balance = await erc20Two.balanceOf(alice.address);
    expect(balance).to.equal(mintAmount);
  });
});
