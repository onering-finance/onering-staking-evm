const { expect } = require("chai");
const { ethers } = require("hardhat");


// const ownerBalance = await hardhatToken.balanceOf(owner.address);


// transfer and expect
//await hardhatToken.transfer(addr1.address, 50);
  //  expect(await hardhatToken.balanceOf(addr1.address)).to.equal(50);

describe("Greeter", async function () {
  
  let RewardFactory;
  let rewardToken;
  let StakingFactory;
  let stakingContract;
  let owner;
  let staker1;
  let staker2;

  it("Make sure deployment is ok", async function () {
    [owner, staker1, staker2] = await ethers.getSigners(); // 3 addresses
    RewardFactory = await ethers.getContractFactory("Ring");
    rewardToken = await RewardFactory.deploy();
    const ownerBalance = await rewardToken.balanceOf(owner.address);
    expect(await rewardToken.totalSupply()).to.equal(ownerBalance);

    await rewardToken.transfer(staker1.address, 50); // transfer 50 tokens to addr1
    expect(await rewardToken.balanceOf(staker1.address)).to.equal(50);


    await rewardToken.connect(staker1).transfer(rewardToken.address, 25); // .connect(signer) is used to send a tx from another account
    expect(await rewardToken.balanceOf(staker1.address)).to.equal(25);

    StakingFactory = await ethers.getContractFactory("RingFarm"); // smart contract deployer
    stakingContract = await StakingFactory.deploy(); // object having all smart contract functions
    await stakingContract.deployed();

    await await rewardToken.connect(staker1).transfer(stakingContract.address, 25);
    expect(await rewardToken.balanceOf(stakingContract.address)).to.equal(25);
  });


  it("Set reward token and send rewards tokens to contract", async function () {
    
    await stakingContract.changeAllowedToken(rewardToken.address);
    await stakingContract.changeRewardToken(rewardToken.address);
  
    expect(await rewardToken.balanceOf(stakingContract.address)).to.equal(25);

    // Approve staking contract
    await rewardToken.approve(stakingContract.address, 1200);
    await stakingContract.addRewards(1200);

    // Expect reward to have increased
    expect(await rewardToken.balanceOf(stakingContract.address)).to.equal(1225);

    expect(await stakingContract.getAllowedToken()).to.equal(rewardToken.address);
  });
});
