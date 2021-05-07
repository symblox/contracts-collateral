import { ethers, waffle } from "hardhat";
import { expect, use } from "chai";
import { BigNumber, Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { formatBytes32String, parseEther } from "ethers/lib/utils";

use(waffle.solidity);

describe("Connector", function () {
  let deployer: SignerWithAddress,
    admin: SignerWithAddress,
    alice: SignerWithAddress;

  let scToken: Contract,
    strategyIdle: Contract,
    erc20: Contract,
    wbnb: Contract,
    connector: Contract,
    collateral: Contract,
    usd: Contract,
    priceGetter: Contract;

  beforeEach(async function () {
    [deployer, admin, alice] = await ethers.getSigners();

    const WBNB = await ethers.getContractFactory("WBNB");
    wbnb = await WBNB.deploy();

    const ER20 = await ethers.getContractFactory("MockERC20");
    erc20 = await ER20.deploy("DAI", "DAI");
    usd = await ER20.deploy("USD", "USD");

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

    const Collateral = await ethers.getContractFactory("MockCollateral");
    collateral = await Collateral.deploy(usd.address, scToken.address);
    await usd.mint(collateral.address, parseEther("100000000"));

    const Connector = await ethers.getContractFactory("Connector");
    connector = await Connector.deploy(
      deployer.address,
      collateral.address,
      usd.address
    );
  });

  it("stake DAI and mint usd", async () => {
    const stakeAmount = parseEther("1");
    const burnAmount = parseEther("1");
    await erc20.mint(deployer.address, stakeAmount);
    await erc20.approve(connector.address, stakeAmount);

    await connector.stakeAndBuild(scToken.address, stakeAmount, stakeAmount);

    let usdBalance = await usd.balanceOf(deployer.address);
    expect(usdBalance).to.equal(stakeAmount);

    await usd.approve(connector.address, burnAmount);
    await connector.burnAndUnstake(scToken.address, burnAmount, burnAmount);

    usdBalance = await usd.balanceOf(deployer.address);
    expect(usdBalance).to.equal(stakeAmount.sub(burnAmount));
  });

  it("collateral and redeem", async () => {
    const collateralAmount = parseEther("1");
    const redeemAmount = parseEther("1");
    await erc20.mint(deployer.address, collateralAmount);

    let erc20Balance = await erc20.balanceOf(deployer.address);
    expect(erc20Balance).to.equal(collateralAmount);

    await erc20.approve(connector.address, collateralAmount);

    await connector.collateral(scToken.address, collateralAmount);

    erc20Balance = await erc20.balanceOf(deployer.address);
    expect(erc20Balance).to.equal(0);

    await connector.redeem(scToken.address, redeemAmount);

    erc20Balance = await erc20.balanceOf(deployer.address);
    expect(erc20Balance).to.equal(redeemAmount);
  });
});
