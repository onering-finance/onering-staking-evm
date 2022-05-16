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
    RewardFactory = await ethers.getContractFactory("contracts/Ring.sol:Ring");
    rewardToken = await RewardFactory.deploy();
    const ownerBalance = await rewardToken.balanceOf(owner.address);
    expect(await rewardToken.totalSupply()).to.equal(ownerBalance);

    await rewardToken.transfer(staker1.address, 50); // transfer 50 tokens to addr1
    expect(await rewardToken.balanceOf(staker1.address)).to.equal(50);


    await rewardToken.connect(staker1).transfer(rewardToken.address, 25); // .connect(signer) is used to send a tx from another account
    expect(await rewardToken.balanceOf(staker1.address)).to.equal(25);

    StakingFactory = await ethers.getContractFactory("contracts/RingFarm.sol:RingFarm"); // smart contract deployer
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


  it("Test staking pause / unpause", async function () {
    
    // Give 1000 tokens for staker1
    await rewardToken.transfer(staker1.address, 1000);
    await rewardToken.connect(staker1).approve(stakingContract.address, 400);
    await expect(stakingContract.connect(staker1).stakeTokens(200)).to.be.revertedWith('Staking is currently paused');


    // make sure not anyone can unpause staking
    await expect(stakingContract.connect(staker1).unpauseStaking()).to.be.reverted;

    // unpause staking
    await stakingContract.unpauseStaking();

    // make sure not anyone can pause staking
    await expect(stakingContract.connect(staker1).pauseStaking()).to.be.reverted;

    // pause staking
    await stakingContract.pauseStaking();
    await expect(stakingContract.connect(staker1).stakeTokens(200)).to.be.revertedWith('Staking is currently paused');
  });

  it("Test staking", async function () {
    // unpause staking
    await stakingContract.unpauseStaking();
    await stakingContract.connect(staker1).stakeTokens(200);
    await stakingContract.setRewardsPerDay(1000);
    expect((await stakingContract.getStakersInfo(staker1.address)).stakingBalance).to.equal(200);
    expect(await stakingContract.getTotalStaked()).to.equal(200);

    
    // User owns all the staking pool and checks rewards after 12 hours, should have 500 (1000 daily rewards / 2).
    
    // increase time by 2 hours
    await ethers.provider.send('evm_increaseTime', [7200]);
    await ethers.provider.send('evm_mine');
    expect(((await stakingContract.getUserRewards(staker1.address))/1e18).toFixed(4)).to.equal('83.3449');

    // test restaking
    await stakingContract.connect(staker1).stakeTokens(1);

    // increase time by 10 hours
    await ethers.provider.send('evm_increaseTime', [36000]);
    await ethers.provider.send('evm_mine');
    expect(((await stakingContract.getUserRewards(staker1.address))/1e18).toFixed(4)).to.equal('500.0231');
});

it("Staker2 joins", async function () {
    
  // give staker2 500 tokens, stake them
  await rewardToken.transfer(staker2.address, 500);
  await rewardToken.connect(staker2).approve(stakingContract.address, 200);
  await stakingContract.connect(staker2).stakeTokens(200);
  expect((await stakingContract.getStakersInfo(staker2.address)).stakingBalance).to.equal(200);
  expect(await stakingContract.getTotalStaked()).to.equal(401);
  
  // User owns half the staking pool and checks rewards after 12 hours, should have 250 (500 remaining daily rewards / 2).
  // and staker 1 should have 750
  
  // increase time by 12 hours
  await ethers.provider.send('evm_increaseTime', [43200]);
  await ethers.provider.send('evm_mine');

  expect(((await stakingContract.getUserRewards(staker2.address))/1e18).toFixed(4)).to.equal('249.3766');

  expect(((await stakingContract.getUserRewards(staker1.address))/1e18).toFixed(4)).to.equal("750.6813");
});

it("Stakers claims rewards", async function () {

  let staker1Balance = await rewardToken.balanceOf(staker1.address);
  await stakingContract.getUserRewards(staker1.address);
  let rewardsToClaim = (await stakingContract.getUserRewards(staker1.address)).div(ethers.utils.parseEther('1'));
  await stakingContract.connect(staker1).claimRewards(rewardsToClaim);
  expect(await rewardToken.balanceOf(staker1.address)).to.equal(staker1Balance.add(rewardsToClaim));

  // Staker2 withdraw with wrong amount, expect revert
  let staker2Balance = await rewardToken.balanceOf(staker2.address);
  await stakingContract.getUserRewards(staker2.address);
  let rewards2ToClaim = (await stakingContract.getUserRewards(staker2.address)).div(ethers.utils.parseEther('1'));
  await expect (stakingContract.connect(staker2).claimRewards(rewardsToClaim)).to.be.revertedWith('Cannot withdraw more than the total rewards balance');
  await stakingContract.connect(staker2).claimRewards(rewards2ToClaim);
  expect(await rewardToken.balanceOf(staker2.address)).to.equal(staker2Balance.add(rewards2ToClaim));

});


it("Withdrawal simulation", async function () {
  let staker1Balance = await rewardToken.balanceOf(staker1.address);
  let staker1Staked = (await stakingContract.getStakersInfo(staker1.address)).stakingBalance;

  await stakingContract.initLockPeriod();
  expect(await stakingContract.getWithdrawReleaseDate()).to.equal((await ethers.provider.getBlock(await ethers.provider.getBlockNumber())).timestamp + 90 * 24 * 60 * 60);

  await expect (stakingContract.connect(staker1).withdraw(staker1Staked, false)).to.be.revertedWith('You cannot withdraw yet');
  //expect(await rewardToken.balanceOf(staker1.address)).to.equal(staker1Balance.add(rewardsToClaim));

  await ethers.provider.send('evm_increaseTime', [90 * 24 * 60 * 50]);
  await ethers.provider.send('evm_mine');
  await expect (stakingContract.connect(staker1).withdraw(staker1Staked, false)).to.be.revertedWith('ou cannot withdraw yet');


  await ethers.provider.send('evm_increaseTime', [90 * 24 * 60 * 15]);
  await ethers.provider.send('evm_mine');
  await stakingContract.connect(staker1).withdraw(staker1Staked, false);

  expect(await rewardToken.balanceOf(staker1.address)).to.equal(staker1Balance.add(staker1Staked));
  expect((await stakingContract.getStakersInfo(staker1.address)).stakingBalance).to.equal(0);
});

it("Ownership", async function () {
  await expect (stakingContract.connect(staker1).withdrawAdmin()).to.be.reverted;
  await stakingContract.transferOwnership(staker1.address);
  await stakingContract.connect(staker1).withdrawAdmin();
});

});

