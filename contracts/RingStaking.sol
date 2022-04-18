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
    uint256 totalPendingRewards; // total amount of rewards to be distributed

    uint256 private rewardsPerDay; // rewards per day
    address[] public stakers; // array of stakers addresses used to iterate over map
    // owner -> balance
    mapping(address => stakingInfo) stakingDetails;  // map containing the details of each user (check the struct)


    constructor(address _dappTokenAddress) public { 
        stakedToken = IERC20(_dappTokenAddress);
    }

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

    // unstakeTokens
    function unstakeTokens(uint256 amount) public{
        //require(token is Ring)
        require(!stakingPaused, "Staking is currently paused");
        require(amount > 0, "Amount cannot be 0");
        require(amount <= stakingDetails[msg.sender].stakingBalance);
        IERC20(allowedToken).transferFrom(address(this), msg.sender, amount);
        stakingDetails[msg.sender].stakingBalance  -= amount;
        totalStaked -= amount;
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

    // calculate rewards
    //TO DO: Call this function at every block
    function calculateRewards() private {

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