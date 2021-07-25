const { expect } = require("chai");
const { ethers, deployments, getNamedAccounts } = require("hardhat");

describe("Contract deployments", function () {
  let token, staking;
  let decimals = 7;
  const t = (tkn) => BigInt(tkn * 10 ** decimals);

  before("Deploy", async function () {
    const [deployer, alice, bob, john, sam] = await ethers.getSigners();

    await deployments.fixture(["SSTKStaking"], deployer);
    token = await ethers.getContract("dummyToken", deployer);
    staking = await ethers.getContract("SSTKStaking", deployer);

    console.log(
      `Token was deployed at ${token.address}  \n Staking was deployed at ${staking.address}`
    );

    await token.transfer(alice.address, t(350000000));
    await token.transfer(bob.address, t(1750000000));
    await token.transfer(john.address, t(1750000000));
    await token.transfer(staking.address, t(17500000000));
    await token.transfer(sam.address, t(10000000000));

    expect(await token.balanceOf(alice.address)).to.equal(t(350000000));
    expect(await token.balanceOf(bob.address)).to.equal(t(1750000000));
    expect(await token.balanceOf(john.address)).to.equal(t(1750000000));
  });

  it("Membership levels", async function () {
    expect(
      staking.addMembership(BigInt(3500000000 * 10 ** decimals), 10000)
    ).to.be.revertedWith("New threshold must be larger than the last");
    expect(
      staking.addMembership(BigInt(3500000001 * 10 ** decimals), 10)
    ).to.be.revertedWith("New APY must be larger than the last");

    expect(await staking.levelsCount()).to.equal(5);
    await staking.addMembership(BigInt(5000000000 * 10 ** decimals), 180);
    expect(await staking.levelsCount()).to.equal(6);

    expect(staking.removeMembership(6)).to.be.revertedWith("Wrong index");
    expect(await staking.levelsCount()).to.equal(6);

    await staking.removeMembership(5);
    expect(await staking.levelsCount()).to.equal(5);

    expect(
      staking.changeMembershipThreshold(3, BigInt(10000000000 * 10 ** decimals))
    ).to.be.revertedWith("Cannot be higher than next lvl");

    expect(
      staking.changeMembershipThreshold(4, BigInt(100000000 * 10 ** decimals))
    ).to.be.revertedWith("Cannot be lower than previous lvl");

    await staking.changeMembershipThreshold(
      3,
      BigInt(1200000000 * 10 ** decimals)
    );

    expect(staking.changeMembershipAPY(3, 1000)).to.be.revertedWith(
      "Cannot be higher than next lvl"
    );

    expect(staking.changeMembershipAPY(3, 10)).to.be.revertedWith(
      "Cannot be lower than previous lvl"
    );

    await staking.changeMembershipAPY(3, 130);
    expect(await staking.getAPY(BigInt(1500000000 * 10 ** decimals))).to.equal(
      130
    );
  });

  it("Staking", async function () {
    const hours = 60 * 60;
    const days = 24 * hours;
    const months = 30 * days;
    const passTime = async (timeSec) => {
      await ethers.provider.send("evm_increaseTime", [timeSec]);
      await ethers.provider.send("evm_mine");
    };

    const [deployer, alice, bob, john, sam] = await ethers.getSigners();

    const MAX = BigInt(2 ** 255);

    await token.connect(alice).approve(staking.address, MAX);
    await token.connect(bob).approve(staking.address, MAX);
    await token.connect(john).approve(staking.address, MAX);
    await token.connect(sam).approve(staking.address, MAX);

    //check stake
    expect(staking.connect(alice).stake(10)).to.be.revertedWith(
      "Cannot stake such few tokens"
    );

    expect((await staking.getStakeInfo(bob.address)).staked).to.equal("0");
    await staking.connect(bob).stake(t(250000000));

    expect((await staking.getStakeInfo(bob.address)).staked).to.equal(
      t(250000000)
    );

    await staking.connect(bob).stake(t(250000000));
    expect((await staking.getStakeInfo(bob.address))[1]).to.equal(80);
    await staking.connect(bob).stake(t(250000000));

    expect((await staking.getStakeInfo(bob.address))[1]).to.equal(100);
    await staking.connect(alice).stake(t(250000000));
    await passTime(360 * days);
    expect(await token.balanceOf(staking.address)).to.equal(t(18500000000));
    expect(await staking.getReward(alice.address)).to.equal(
      BigInt(t(15000000))
    );

    //check unstake
    const twoYearsAfter = 720 * days;
    await staking.connect(john).stake(t(750000000));
    await passTime(twoYearsAfter);
    await staking.connect(john).unstake();
    expect((await staking.Stakes(john.address)).staked).to.equal(0);
    expect((await staking.Stakes(john.address)).lastWithdrawnTime).to.equal(0);
    expect((await staking.Stakes(john.address)).cooldown).to.equal(0);

    await staking.connect(john).stake(t(1000000000));
    expect((await staking.getStakeInfo(john.address)).apy).to.equal(100);
    await passTime(180 * days);
    expect(await staking.getReward(john.address)).to.equal(t(50000000));
    await staking.connect(john).unstake();
    await staking.connect(alice).unstake();
    await staking.connect(bob).unstake();

    //check claim
    expect(staking.connect(sam).claim()).to.be.revertedWith("Nothing to claim");
    expect((await staking.Stakes(sam.address)).staked).to.equal(0);
    expect(await token.balanceOf(sam.address)).to.equal(t(10000000000));

    await staking.connect(sam).stake(t(1000000000));
    expect((await staking.getStakeInfo(sam.address))[1]).to.equal(100);
    await passTime(360 * days - 1); //+1 block due to claim
    await staking.connect(sam).claim();
    expect(staking.connect(sam).claim()).to.be.revertedWith("Nothing to claim");
    expect(await token.balanceOf(sam.address)).to.equal(t(9100000000));
    expect((await staking.getStakeInfo(sam.address))[0]).to.equal(
      t(1000000000)
    );
  });
});
