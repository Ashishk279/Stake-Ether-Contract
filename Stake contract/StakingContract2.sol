//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor() ERC20("MyToken", "MTK") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract StakingToken is MyToken {
    MyToken private tokenAddress;
    address immutable contractOwner;

    struct stake {
        uint256 id;
        uint256 stakeAmount;
        uint256 stakingStart;
        uint256 stakingEnd;
        uint256 stakingDuration;
        uint256 rewardRate;
        bool isStakingActive;
    }

    struct reward {
        uint256 id;
        uint256 totalReward;
        uint256 claimRewardPerDay;
        uint256 claimedReward;
    }
    mapping(address => mapping(uint256 => stake)) public stakeDetails;
    mapping(address => mapping(uint256 => reward)) public rewardDetails;

    constructor(address token_address) {
        require(token_address != address(0), "Address != 0.");
        tokenAddress = MyToken(token_address);
        contractOwner = msg.sender;
    }

    function _checkContractOwner() internal view {
        require(msg.sender == contractOwner, "Only owner.");
    }

    modifier onlyContractOwner() {
        _checkContractOwner();
        _;
    }

    function MintToken(uint256 tokens) public payable onlyContractOwner {
        require(tokens > 0, "Tokens > 0");
        tokenAddress.mint(address(this), tokens);
    }

    function startStaking(uint256 duration, uint256 id) public payable {
        require(msg.sender != contractOwner, "Owner address");
        require(msg.value > 100, "Staking Amount should be greater then 100");
        require(duration > 0, "Taking duration as a minute.");
        reward memory checkreward = rewardDetails[msg.sender][id];
        stake memory stakeEthers = stakeDetails[msg.sender][id];

        require(!stakeEthers.isStakingActive, "Already stake");
        stakeEthers.id = id;
        stakeEthers.stakingStart = block.timestamp;
        stakeEthers.stakeAmount += msg.value;
        stakeEthers.stakingDuration = duration;
        stakeEthers.stakingEnd = (block.timestamp + duration * 1 minutes);
        stakeEthers.rewardRate = 10;
        stakeEthers.isStakingActive = true;
        stakeDetails[msg.sender][id] = stakeEthers;

        (uint256 rewardAmount, uint256 claimedReward) = calculateReward(
            msg.value,
            stakeEthers.rewardRate,
            duration
        );

        checkreward.id = id;
        checkreward.totalReward += rewardAmount;
        checkreward.claimRewardPerDay += claimedReward;
        rewardDetails[msg.sender][id] = checkreward;
    }

    function calculateReward(
        uint256 amount,
        uint256 rewardRate,
        uint256 duration
    ) private pure returns (uint256, uint256) {
        uint256 totalReward = (amount * rewardRate * duration) / 100;
        uint256 claimedReward = totalReward / duration;
        return (totalReward, claimedReward);
    }

    function increaseStakeAmount(uint256 _id) public payable {
        require(msg.value > 0, "Staking Amount > 0");
        stake memory stakeEthers = stakeDetails[msg.sender][_id];
        require(stakeEthers.id == _id, "Id not matched");
        require(stakeEthers.isStakingActive, "You are not staking");
        require(
            block.timestamp < stakeEthers.stakingEnd,
            "Staking duration has ended"
        );
        uint256 additionalAmount = msg.value;
        (uint256 rewardAmount, uint256 claimedReward) = calculateReward(
            additionalAmount,
            stakeEthers.rewardRate,
            (stakeEthers.stakingEnd - block.timestamp) / 60
        );
        stakeEthers.stakeAmount += additionalAmount;
        stakeEthers.stakingStart = block.timestamp;
        reward memory checkReward = rewardDetails[msg.sender][_id];
        checkReward.totalReward += rewardAmount;
        checkReward.claimRewardPerDay += claimedReward;
        rewardDetails[msg.sender][_id] = checkReward;
        stakeDetails[msg.sender][_id] = stakeEthers;
    }

    function claimReward(uint256 rewardAmount, uint256 id) public {
        stake memory stakeEthers = stakeDetails[msg.sender][id];
        require(
            block.timestamp > stakeEthers.stakingStart + 1 minutes ||
                block.timestamp >= stakeEthers.stakingEnd,
            "Claim reward after 1 min if staking duration ended then you can claim all reward."
        );
        reward memory claim = rewardDetails[msg.sender][id];
        if (block.timestamp >= stakeEthers.stakingEnd) {
            tokenAddress.transfer(msg.sender, claim.totalReward);
        } else {
            require(
                rewardAmount <= claim.claimRewardPerDay &&
                    claim.totalReward != 0,
                "Amount <= claimed Amount per day"
            );
            tokenAddress.transfer(msg.sender, claim.claimRewardPerDay);
        }
        claim.totalReward -= rewardAmount;
        claim.claimedReward += rewardAmount;
        stakeEthers.stakingStart = block.timestamp;
        rewardDetails[msg.sender][id] = claim;
        stakeDetails[msg.sender][id] = stakeEthers;
    }

    function withdrawStake(uint256 stakeAmount, uint256 id) public payable {
        stake memory stakeEthers = stakeDetails[msg.sender][id];
        require(
            block.timestamp > stakeEthers.stakingEnd,
            "Stake time not ended."
        );
        require(stakeEthers.isStakingActive, "Need to stake ether.");
        require(
            stakeAmount > 0 && stakeAmount <= stakeEthers.stakeAmount,
            "Check stake Amount"
        );
        reward memory claim = rewardDetails[msg.sender][id];
        if (stakeEthers.stakeAmount == stakeAmount) {
            require(claim.totalReward == 0, "Claim Your amount");
            claim.id = 0;
            claim.claimRewardPerDay = 0;
            claim.claimedReward = 0;
            rewardDetails[msg.sender][id] = claim;
            delete stakeDetails[msg.sender][id];
        } else {
            stakeEthers.stakeAmount -= stakeAmount;
            stakeDetails[msg.sender][id] = stakeEthers;
        }
        payable(msg.sender).transfer(stakeAmount);
    }
}
