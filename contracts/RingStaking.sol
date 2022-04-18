pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/erc20/erc20.sol";

contract Ring is ERC20 {
    constructor() ERC20("OneRing","RING"){
        _mint(msg.sender, 1000000000000);
    }
}



struct stakingInfo {
        uint256 stakingBalance;  // total amount staked by user
        uint256 stakingRewards; // total pending rewards of user
        uint256 amountToWithdraw; // amount requested to withdraw
        uint256 withdrawReleaseDate;  // release date of the requested withdraw
        bool stakerMarked; // marks if staker was added in stakers array, to avoid adding twice
        bool withdrawRequested; // marks if a withdrawal is ongoing
    }


contract RingFarm is Ownable {
    address allowedToken; // token address that is allowed to be staked
    address rewardToken; // token address that is distributed in rewards
    bool stakingPaused = true; // bool marking whether staking is paused or not
    IERC20 public stakedToken;

    uint256 totalStaked; // total amount of staked tokens
    uint256 rewardsBalance; // total amount of reward tokens
    uint256 public totalClaimed; // total amount of claimed rewards
    uint256 totalPendingRewards; // total amount of rewards to be distributed
    uint256 withdrawDuration; // Amount of time to wait after requesting a withdrawal,
    uint256 private rewardsPerDay; // rewards per day
    uint256 public lastTimeStamp; // last timestamp on which rewards were updated
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
        require(amount < rewardsBalance - totalPendingRewards, "Cannot leave less than you have to reward");
        IERC20(rewardToken).transferFrom(address(this), msg.sender, amount);
        rewardsBalance -= amount;
    }

    // stakeTokens
    function stakeTokens(uint256 amount) public{
        //require(token is Ring)
        require(!stakingPaused, "Staking is currently paused");
        require(amount > 0, "Amount cannot be 0");
        IERC20(allowedToken).transferFrom(msg.sender, address(this), amount);
        //check if staker already in array
        if(!stakingDetails[msg.sender].stakerMarked){
            stakers.push(msg.sender);
            stakingDetails[msg.sender].stakerMarked = true;
        }
        stakingDetails[msg.sender].stakingBalance += amount;
        totalStaked += amount;
    }

    // withdraw or unstake Tokens
    function withdrawTokens(uint256 amount) public{
        //require(token is Ring)
        require(!stakingPaused, "Staking is currently paused");
        require(amount > 0, "Amount cannot be 0");
        require(stakingDetails[msg.sender].stakingBalance > 0);
        require(amount <= stakingDetails[msg.sender].stakingBalance, "Cannot withdraw more than what is staked");
        require(!stakingDetails[msg.sender].withdrawRequested, "A withdrawal is already requested");
        initWithdraw(amount);
        IERC20(allowedToken).transferFrom(address(this), msg.sender, amount);
        stakingDetails[msg.sender].stakingBalance  -= amount;
        totalStaked -= amount;
    }

    function initWithdraw(uint256 amount) private{
        require(amount <= stakingDetails[msg.sender].stakingBalance, "Cannot withdraw more than what is staked");
        require(!stakingDetails[msg.sender].withdrawRequested, "A withdrawal is already requested");
        stakingDetails[msg.sender].amountToWithdraw = amount;
        stakingDetails[msg.sender].withdrawRequested = true;
        stakingDetails[msg.sender].withdrawReleaseDate = block.timestamp + 2 weeks;
    }

    function finalizeWithdraw(uint256 amount, bool andClaim) public{
        require(stakingDetails[msg.sender].stakingBalance > 0);
        require(amount <= stakingDetails[msg.sender].stakingBalance, "Cannot withdraw more than what is staked");
        require(stakingDetails[msg.sender].withdrawRequested, "A withdrawal is already requested");
        require(block.timestamp > stakingDetails[msg.sender].withdrawReleaseDate, "You cannot withdraw yet");
        if(andClaim){
            claimRewards(amount);
        }
        require(IERC20(allowedToken).transfer(msg.sender,amount));
        stakingDetails[msg.sender].stakingBalance -= amount;
        stakingDetails[msg.sender].withdrawRequested = false;
    }


    // get rewards per day
    function getRewardsPerDay() public view returns (uint256){
        return rewardsPerDay;
    }

    // set rewards per day
    function setRewardsPerDay(uint256 rewards) public onlyOwner{
        require(rewards >= 0);
        rewardsPerDay = rewards;
    }

    // get rewards per day
    function getWithdrawalDuration() public view returns (uint256){
        return withdrawDuration;
    }

    // set rewards per day
    function setWithdrawalDuration(uint256 timeToWaitInDays) public onlyOwner{
        withdrawDuration = timeToWaitInDays ;
    }

    // calculate rewards
    //TO DO: Call this function at every block
    function calculateRewards() private {
        address stakerAddress;
        uint256 stakerShare;
        for (uint i=0; i<stakers.length; i++) {
            stakerAddress = stakers[i];
            stakerShare = stakingDetails[stakerAddress].stakingBalance / totalStaked;
            //staking rewards of each user is increased by the staker's share x rewards per day x seconds passed since last update divided by seconds per day.
            stakingDetails[stakerAddress].stakingRewards += stakerShare * rewardsPerDay * (block.timestamp - lastTimeStamp)/86400;
        }
    }

    // claim rewards
    function claimRewards(uint256 amount) public {
        require(stakingDetails[msg.sender].stakerMarked); // require that the caller is a staker
        require(stakingDetails[msg.sender].stakingRewards > 0); // require that the caller has rewards
        require(amount <= stakingDetails[msg.sender].stakingRewards);
        IERC20(rewardToken).transferFrom(address(this), msg.sender, amount);
        rewardsBalance -= amount;
        totalPendingRewards -= amount;
        totalClaimed += amount;
    }

    

    // changeAllowedToken
    function changeAllowedToken(address token) public onlyOwner {
        allowedToken = token;
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
}