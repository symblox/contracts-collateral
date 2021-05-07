import { ethers, waffle } from "hardhat";
import { expect, use } from "chai";
import { BigNumber, Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { formatBytes32String, parseEther } from "ethers/lib/utils";

use(waffle.solidity);

describe("SingleSCToken", function () {
  let deployer: SignerWithAddress,
    admin: SignerWithAddress,
    alice: SignerWithAddress;

  let scToken: Contract,
    strategyIdle: Contract,
    erc20: Contract,
    wbnb: Contract,
    priceGetter: Contract;

  beforeEach(async function () {
    [deployer, admin, alice] = await ethers.getSigners();

    const WBNB = await ethers.getContractFactory("WBNB");
    wbnb = await WBNB.deploy();

    const ER20 = await ethers.getContractFactory("MockERC20");
    erc20 = await ER20.deploy("SYX", "SYX");

    const MockPrice = await ethers.getContractFactory("MockPrice");
    priceGetter = await MockPrice.deploy();
    await priceGetter.setPrice(formatBytes32String("SYX"), parseEther("1"));

    const StrategyIdle = await ethers.getContractFactory("StrategyIdle");
    strategyIdle = await StrategyIdle.deploy();
    await strategyIdle
      .connect(deployer)
      .__StrategyIdle_init(admin.address, erc20.address);

    const SingleSCToken = await ethers.getContractFactory("SingleSCToken");
    scToken = await SingleSCToken.deploy();
    await scToken
      .connect(deployer)
      .__SingleSCToken_init(
        admin.address,
        "scToken",
        "scToken",
        erc20.address,
        wbnb.address,
        strategyIdle.address,
        priceGetter.address
      );
    await strategyIdle.transferOwnership(scToken.address);
  });

  it("deposit and withdraw BNB", async () => {
    const depositAmount = parseEther("1");
    //token != wbnb
    await expect(scToken.connect(alice).depositBNB(0)).to.revertedWith(
      "not bnb"
    );

    const StrategyIdle = await ethers.getContractFactory("StrategyIdle");
    strategyIdle = await StrategyIdle.deploy();
    await strategyIdle
      .connect(deployer)
      .__StrategyIdle_init(admin.address, wbnb.address);
    const SingleSCToken = await ethers.getContractFactory("SingleSCToken");
    scToken = await SingleSCToken.deploy();
    //token == wbnb
    await scToken
      .connect(deployer)
      .__SingleSCToken_init(
        admin.address,
        "scToken",
        "scToken",
        wbnb.address,
        wbnb.address,
        strategyIdle.address,
        priceGetter.address
      );
    await strategyIdle.transferOwnership(scToken.address);

    await expect(scToken.connect(alice).depositBNB(0)).to.revertedWith(
      "deposit must be greater than 0"
    );

    await scToken.connect(alice).depositBNB(0, { value: depositAmount });
    let balanceStrategy = await scToken.balanceStrategy();
    expect(balanceStrategy).to.equal(depositAmount);

    const scTokenBalance = await scToken.balanceOf(alice.address);
    await scToken.connect(alice).withdrawBNB(scTokenBalance, 0);
    balanceStrategy = await scToken.balanceStrategy();
    expect(balanceStrategy).to.equal(0);
  });

  it("deposit and withdraw erc20", async () => {
    const depositAmount = parseEther("1");
    await erc20.mint(alice.address, depositAmount);
    await erc20.connect(alice).approve(scToken.address, depositAmount);
    await expect(scToken.connect(alice).deposit(0, 0)).to.revertedWith(
      "deposit must be greater than 0"
    );

    await scToken.connect(alice).deposit(depositAmount, 0);
    let balanceStrategy = await scToken.balanceStrategy();
    expect(balanceStrategy).to.equal(depositAmount);

    const pricePerFullShare = await scToken.getPricePerFullShare();
    //Because the price is set to 1, pricePerFullShare should be equal to 1
    expect(pricePerFullShare).to.equal(parseEther("1"));

    const sharesToAmount = await scToken.sharesToAmount(parseEther("1"));
    expect(sharesToAmount).to.equal(parseEther("1"));
    const amountToShares = await scToken.amountToShares(parseEther("1"));
    expect(amountToShares).to.equal(parseEther("1"));

    const scTokenBalance = await scToken.balanceOf(alice.address);
    await scToken.connect(alice).withdraw(scTokenBalance, 0);
    balanceStrategy = await scToken.balanceStrategy();
    expect(balanceStrategy).to.equal(0);
  });

  it("if paused deposit and withdraw can not call", async () => {
    const depositAmount = parseEther("1");
    await erc20.mint(alice.address, depositAmount);
    await erc20.connect(alice).approve(scToken.address, depositAmount);

    //only govAddress can call pause
    await expect(scToken.connect(alice).pauseDeposit()).to.revertedWith(
      "Not authorized"
    );
    await scToken.connect(admin).pauseDeposit();

    await expect(
      scToken.connect(alice).deposit(depositAmount, 0)
    ).to.revertedWith("deposit paused");

    //only govAddress can call pause
    await expect(scToken.connect(alice).unpauseDeposit()).to.revertedWith(
      "Not authorized"
    );
    await scToken.connect(admin).unpauseDeposit();

    await expect(scToken.connect(alice).deposit(depositAmount, 0));

    //only govAddress can call pause
    await expect(scToken.connect(alice).pauseWithdraw()).to.revertedWith(
      "Not authorized"
    );
    await scToken.connect(admin).pauseWithdraw();

    await expect(
      scToken.connect(alice).withdraw(depositAmount, 0)
    ).to.revertedWith("withdraw paused");

    await scToken.connect(admin).unpauseWithdraw();

    await expect(scToken.connect(alice).withdraw(depositAmount, 0));
  });

  it("emergency withdraw", async () => {
    const ER20 = await ethers.getContractFactory("MockERC20");
    const erc20Two = await ER20.deploy("DAI", "DAI");

    //scToken starting balance is 0
    let balance = await erc20Two.balanceOf(scToken.address);
    expect(balance).to.equal(0);

    const mintAmount = parseEther("1");
    await erc20Two.mint(scToken.address, mintAmount);

    //mint 1 to strategyIdle
    balance = await erc20Two.balanceOf(scToken.address);
    expect(balance).to.equal(mintAmount);

    //only govAddress can call emergencyWithdraw
    await expect(
      scToken
        .connect(alice)
        .emergencyWithdraw(erc20Two.address, mintAmount, alice.address)
    ).to.revertedWith("!gov");

    //withdraw token can't be self
    await expect(
      scToken
        .connect(admin)
        .emergencyWithdraw(scToken.address, mintAmount, alice.address)
    ).to.revertedWith("!safe");

    await scToken
      .connect(admin)
      .emergencyWithdraw(erc20Two.address, mintAmount, alice.address);

    //all balance has emergencyWithdraw to alice, so balance is 0
    balance = await erc20Two.balanceOf(scToken.address);
    expect(balance).to.equal(0);

    //alice balance is 1
    balance = await erc20Two.balanceOf(alice.address);
    expect(balance).to.equal(mintAmount);
  });
});
