//SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/utils/Arrays.sol";
import "openzeppelin-solidity/contracts/utils/Arrays.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

contract SSTKStaking is Ownable {
    struct Stake {
        uint256 staked;
        uint256 lastWithdrawnTime;
        uint256 cooldown;
    }

    struct MembershipLevel {
        uint256 threshold;
        uint256 APY;
    }

    uint256 private _divider = 1000;
    uint256 private _decimals = 7;
    uint256 private _minimalAdditionalDelay = 20;
    uint256 public rewardPeriod = 7 days;
    uint256 public apyBase = 360 days;
    uint256 public totalTokenLocked;

    mapping(address => Stake) public Stakes;
    MembershipLevel[] public MembershipLevels;
    uint256 public levelsCount = 0;

    IERC20 _token;

    event MembershipAdded(uint256 threshold, uint256 apy, uint256 newLevelsCount);
    event MembershipRemoved(uint256 index, uint256 newLevelsCount);
    event Staked(address fromUser, uint256 amount);
    event Claimed(address byUser, uint256 reward);
    event Unstaked(address byUser, uint256 amount);

    function changeRewardPeriod(uint256 newPeriod) external onlyOwner {
        require(newPeriod > 0, "Cannot be 0");
        rewardPeriod = newPeriod;
    }

    function changeMembershipAPY(uint256 index, uint256 newAPY) external onlyOwner {
        require(index <= levelsCount - 1, "Wrong membership id");
        if (index > 0) require(MembershipLevels[index - 1].APY < newAPY, "Cannot be lower than previous lvl");
        if (index < levelsCount - 1) require(MembershipLevels[index + 1].APY > newAPY, "Cannot be higher than next lvl");
        MembershipLevels[index].APY = newAPY;
    }

    function changeMembershipThreshold(uint256 index, uint256 newThreshold) external onlyOwner {
        require(index <= levelsCount - 1, "Wrong membership id");
        if (index > 0) require(MembershipLevels[index - 1].threshold < newThreshold, "Cannot be lower than previous lvl");
        if (index < levelsCount - 1) require(MembershipLevels[index + 1].threshold > newThreshold, "Cannot be higher than next lvl");
        MembershipLevels[index].threshold = newThreshold;
    }

    function addMembership(uint256 threshold, uint256 APY) public onlyOwner {
        require(threshold > 0 && APY > 0, "Threshold and APY should be larger than zero");
        if (levelsCount == 0) {
            MembershipLevels.push(MembershipLevel(threshold, APY));
        } else {
            require(MembershipLevels[levelsCount - 1].threshold < threshold, "New threshold must be larger than the last");
            require(MembershipLevels[levelsCount - 1].APY < APY, "New APY must be larger than the last");
            MembershipLevels.push(MembershipLevel(threshold, APY));
        }
        levelsCount++;
        emit MembershipAdded(threshold, APY, levelsCount);
    }

    function removeMembership(uint256 index) external onlyOwner {
        require(levelsCount > 0, "Nothing to remove");
        require(index <= levelsCount - 1, "Wrong index");

        for (uint256 i = index; i < levelsCount - 1; i++) {
            MembershipLevels[i] = MembershipLevels[i + 1];
        }
        delete MembershipLevels[levelsCount - 1];
        levelsCount--;
        emit MembershipRemoved(index, levelsCount);
    }

    function setToken(address token) public onlyOwner {
        _token = IERC20(token);
    }

    function getStakeInfo(address user)
        external
        view
        returns (
            uint256 staked,
            uint256 apy,
            uint256 lastClaimed,
            uint256 cooldown
        )
    {
        return (Stakes[user].staked, getAPY(Stakes[user].staked), Stakes[user].lastWithdrawnTime, Stakes[user].cooldown);
    }

    function calculateAdditionalTime(uint256 staked, uint256 tokensReceived) public view returns (uint256) {
        uint256 minimalTime = (_minimalAdditionalDelay * rewardPeriod) / _divider;
        uint256 time = (tokensReceived * rewardPeriod) / staked;
        if (time < minimalTime) return minimalTime;
        return time;
    }

    constructor(address token) {
        addMembership(250000000 * 10**_decimals, 60);
        addMembership(500000000 * 10**_decimals, 80);
        addMembership(750000000 * 10**_decimals, 100);
        addMembership(1500000000 * 10**_decimals, 120);
        addMembership(3500000000 * 10**_decimals, 150);
        setToken(token);
    }

    function canClaim(address user) public view returns (bool) {
        return (getReward(user) > 0);
    }

    function getAPY(uint256 tokens) public view returns (uint256) {
        require(levelsCount > 0, "No membership levels exist");

        for (uint256 i = levelsCount; i != 0; i--) {
            uint256 currentAPY = MembershipLevels[i - 1].APY;
            uint256 currentThreshold = MembershipLevels[i - 1].threshold;
            if (currentThreshold <= tokens) {
                return currentAPY;
            }
        }
        return 0;
    }

    function calculateReward(
        uint256 APY,
        uint256 cooldown,
        uint256 lastWithdrawn,
        uint256 tokens
    ) public view returns (uint256) {
        if (block.timestamp - cooldown <= lastWithdrawn) return 0;
        return ((block.timestamp - lastWithdrawn) * tokens * APY) / _divider / apyBase;
    }

    function getReward(address user) public view returns (uint256) {
        require(levelsCount > 0, "No membership levels exist");
        if (Stakes[user].staked == 0) return 0;

        uint256 staked = Stakes[user].staked;
        uint256 lastWithdrawn = Stakes[user].lastWithdrawnTime;
        uint256 APY = getAPY(staked);
        uint256 cooldown = Stakes[user].cooldown;

        return calculateReward(APY, cooldown, lastWithdrawn, staked);
    }

    function stake(uint256 tokens) external {
        require(tokens > 0, "Cannot stake 0");
        require(MembershipLevels[0].threshold <= tokens + Stakes[msg.sender].staked, "Cannot stake such few tokens");
        uint256 currentBalance = _token.balanceOf(address(this));
        _token.transferFrom(msg.sender, address(this), tokens);
        uint256 tokensReceived = _token.balanceOf(address(this)) - currentBalance;
        require(tokensReceived > 0, "Cannot stake 0");

        //if it is the first time then just set lastWithdrawnTime to now
        if (Stakes[msg.sender].staked == 0) {
            Stakes[msg.sender].cooldown = rewardPeriod;
            Stakes[msg.sender].lastWithdrawnTime = block.timestamp;
        } else {
            //In case a user has unclaimed SSTK, add them to the newly staked amount
            uint256 reward = getReward(msg.sender);
            if (reward > 0) {
                Stakes[msg.sender].staked += reward;
                totalTokenLocked += reward;
                Stakes[msg.sender].lastWithdrawnTime = block.timestamp;
                Stakes[msg.sender].cooldown = rewardPeriod;
            }
            //In case a user doesn't have unclaimed tokens but has active stake, top up it and adjust the timer
            else {
                uint256 additionalTime = calculateAdditionalTime(Stakes[msg.sender].staked, tokensReceived);
                Stakes[msg.sender].cooldown = block.timestamp - Stakes[msg.sender].lastWithdrawnTime + additionalTime;
            }
        }

        Stakes[msg.sender].staked += tokensReceived;
        totalTokenLocked += tokensReceived;
        emit Staked(msg.sender, tokensReceived);
    }

    function claim() public {
        require(canClaim(msg.sender), "Nothing to claim");
        uint256 reward = getReward(msg.sender);
        _token.transfer(msg.sender, reward);
        Stakes[msg.sender].lastWithdrawnTime = block.timestamp;
        Stakes[msg.sender].cooldown = rewardPeriod;

        emit Claimed(msg.sender, reward);
    }

    function unstake() external {
        require(Stakes[msg.sender].staked > 0, "Nothing to unstake");

        uint256 reward = getReward(msg.sender);
        uint256 unstakeAmount = Stakes[msg.sender].staked;
        _token.transfer(msg.sender, reward + unstakeAmount);

        totalTokenLocked = totalTokenLocked - reward - unstakeAmount;
        delete Stakes[msg.sender];
        emit Claimed(msg.sender, reward);
        emit Unstaked(msg.sender, unstakeAmount);
    }
}
