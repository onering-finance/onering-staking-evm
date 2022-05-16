pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RingFarm is Ownable {

    struct stakingInfo {
        uint256 stakingBalance;  // total amount staked by user
        uint256 userStakingSnapshot; // last staking rewards snapshot
        uint256 userStakingRewards; // last staking rewards
        uint256 lastUserTimeStamp; // last timestamp on which the user's rewards were updated
        uint256 amountToWithdraw; // amount requested to withdraw
        bool stakerMarked; // marks if staker was added in stakers array, to avoid adding twice
    }

    address allowedToken; // token address that is allowed to be staked
    address rewardToken; // token address that is distributed in rewards
    bool stakingPaused = true; // bool marking whether staking is paused or not
    IERC20 public stakedToken;
    uint256 public withdrawReleaseDate;

    uint256 totalStaked; // total amount of staked tokens
    uint256 rewardsBalance; // total amount of reward tokens
    uint256 public totalClaimed; // total amount of claimed rewards
    uint256 withdrawDuration = 90 days; // Amount of time to wait after requesting a withdrawal,
    uint256 public rewardsPerDay = 2000*1e18; // rewards per day, 2000 by default
    uint256 public snapshot; // rewards snapshot at distribution
    uint256 public lastSnapshotTimestamp; // snapshot's timestamp
    address[] public stakers; // array of stakers addresses used to iterate over map
    // owner -> balance
    mapping(address => stakingInfo) stakingDetails;  // map containing the details of each user (check the struct)

    // addRewards
    function addRewards(uint256 amount) public onlyOwner {
        require(amount > 0, "Amount cannot be 0");
        IERC20(rewardToken).transferFrom(msg.sender, address(this), amount);
        rewardsBalance += amount;
    }

    // WithdrawRewards
    function WithdrawRewards(uint256 amount) public onlyOwner {
        require(amount > 0, "Amount cannot be 0");
        IERC20(rewardToken).transfer(msg.sender, amount);
        rewardsBalance -= amount;
    }

    function updateSnapshot() private{
        require(totalStaked > 0, "Must have tokens being staked");
        snapshot = updatedSnapshotValue();
        lastSnapshotTimestamp = block.timestamp;
    }

    function accumulatedSnapshotValue(uint256 currentReward) private view returns (uint256){
        return snapshot + currentReward;
    }

    function updatedSnapshotValue() private view returns (uint256){
        return accumulatedSnapshotValue((rewardsPerDay * 1e18 * (block.timestamp - lastSnapshotTimestamp)) /  (86400 * totalStaked));
    }

    // stakeTokens
    function stakeTokens(uint256 amount) public{
        //require(token is Ring)
        require(!stakingPaused, "Staking is currently paused");
        require(amount > 0, "Amount cannot be 0");
        IERC20(allowedToken).transferFrom(msg.sender, address(this), amount);
        //check if person is staking more or for the first time
        if(stakingDetails[msg.sender].stakerMarked){
            stakingDetails[msg.sender].userStakingRewards = getUserRewards(msg.sender);
        }
        //check if first staker ever:
        if(totalStaked == 0){
            lastSnapshotTimestamp = block.timestamp;
        }
        else{
            updateSnapshot();
        }

        totalStaked += amount;
        stakingDetails[msg.sender].userStakingSnapshot = snapshot;
        stakingDetails[msg.sender].lastUserTimeStamp = block.timestamp;
        if(!stakingDetails[msg.sender].stakerMarked){
            stakers.push(msg.sender);
            stakingDetails[msg.sender].stakerMarked = true;
        }
        stakingDetails[msg.sender].stakingBalance += amount;

    }

    function withdraw(uint256 amount, bool andClaim) public{
        require(stakingDetails[msg.sender].stakingBalance > 0, "User must have staked tokens");
        require(amount > 0, "Amount cannot be 0");
        require(amount <= stakingDetails[msg.sender].stakingBalance, "Cannot withdraw more than what is staked");
        require(block.timestamp > withdrawReleaseDate, "You cannot withdraw yet");
        updateSnapshot();
        if(andClaim){
            claimRewards(getUserRewards(msg.sender)/1e18);
        }
        require(IERC20(allowedToken).transfer(msg.sender, amount));
        stakingDetails[msg.sender].stakingBalance -= amount;
        totalStaked -= amount;
        updateSnapshot();
    }

    // emergency withdraw
    function withdrawAdmin() public onlyOwner{
        IERC20(rewardToken).transfer(owner(), rewardsBalance);
        IERC20(rewardToken).transfer(owner(), totalStaked);
    }


    // get rewards per day
    function getRewardsPerDay() public view returns (uint256){
        return rewardsPerDay;
    }

    // set rewards per day
    function setRewardsPerDay(uint256 rewards) public onlyOwner{
        require(rewards >= 0, "Cannot set negative rewards");
        rewardsPerDay = rewards;
    }

    // get rewards per day
    function getWithdrawalDuration() public view returns (uint256){
        return withdrawDuration;
    }

    // set withdrawal lock duration, default to 3 months
    function setWithdrawalDuration(uint256 timeToWaitInDays) public onlyOwner{
        require(timeToWaitInDays > 0, "Cannot set negative days");
        withdrawDuration = timeToWaitInDays * 24 * 60 * 60;
    }

    function initLockPeriod() public onlyOwner{
        withdrawReleaseDate = block.timestamp + withdrawDuration;
    }

    function getWithdrawReleaseDate() public view returns (uint256){
        return withdrawReleaseDate;
    }

    function getUserRewards(address stakerAddress) public view returns (uint256){
        if(!stakingDetails[stakerAddress].stakerMarked){   
            return 0;
        }
        return (stakingDetails[stakerAddress].userStakingRewards + 
        (stakingDetails[stakerAddress].stakingBalance * (updatedSnapshotValue() - stakingDetails[stakerAddress].userStakingSnapshot)));
    }

    // claim rewards
    function claimRewards(uint256 amount) public {
        require(stakingDetails[msg.sender].stakerMarked, "User must be marked as a staker"); // require that the caller is a staker
        require(amount <= rewardsBalance, "Cannot withdraw more than the total rewards balance");
        require(amount <= getUserRewards(msg.sender));
        IERC20(rewardToken).transfer(msg.sender, amount);
        rewardsBalance -= amount;
        if(amount > stakingDetails[msg.sender].userStakingRewards){
            stakingDetails[msg.sender].userStakingRewards = 0;
        }
        else{
            stakingDetails[msg.sender].userStakingRewards -= amount;
        }
        totalClaimed += amount;
    }

    

    // changeAllowedToken
    function changeAllowedToken(address token) public onlyOwner {
        allowedToken = token;
    }

    function getAllowedToken() public view returns (address) {
        return allowedToken;
    }

     // changeRewardToken
    function changeRewardToken(address token) public onlyOwner {
        rewardToken = token;
    }

    function getRewardToken() public view returns (address) {
        return rewardToken;
    }

    // pauseStaking
    function pauseStaking() public onlyOwner {
        require(!stakingPaused, "Staking is currently paused");
        stakingPaused = true;
    }

    // unpauseStaking
    function unpauseStaking() public onlyOwner {
        require(stakingPaused, "Staking is currently unpaused");
        stakingPaused = false;
    }

    function getTotalStaked() public view returns (uint256){
        return totalStaked;
    }

    function getStakersInfo(address staker) public view returns (stakingInfo memory){
        return stakingDetails[staker];
    }
}