// contracts/resolv.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ResolvToken.sol";
import "./ResolvApp.sol";

contract ResolvGovernance is Ownable {
    ResolvToken public resolvToken;
    ResolvApp public resolvApp;
    
    
    uint internal constant initialSupply = 1000000000 ether;
    uint internal immutable inceptionTimestamp;
    uint internal immutable inceptionBlock;
    
    struct DistributionFund {
        address fundAddress;
        uint totalAllocated;
        uint totalClaimed;
    }
    
    DistributionFund public developerFund;
    mapping (address => DistributionFund) public giveawayFunds;
    mapping (address => DistributionFund) public stakingFunds;
    uint public giveawayTotalAllocation;
    uint public giveawayAllocationSoFar;
    uint public stakingTotalAllocation;
    uint public stakingAllocationSoFar;
    
    
    constructor() {
        inceptionBlock = block.number;
        inceptionTimestamp = block.timestamp;
        resolvToken = new ResolvToken(initialSupply);
        
        uint defaultPrice = 10 ether;
        uint costPerBlock = 1e15;
        resolvApp = new ResolvApp(defaultPrice, costPerBlock, address(resolvToken));
        // TODO set owner or admin
        
        developerFund = DistributionFund(owner(), (initialSupply / 10) * 3, 0); // 30% allocated to developer fund, 10% initially, another 20% vested over 4 years
        giveawayTotalAllocation = (initialSupply / 10) * 2; // 20% allocated to giveaway funds
        stakingTotalAllocation = (initialSupply / 10) * 5; // 50% allocated to staking funds
        assert(developerFund.totalAllocated + giveawayTotalAllocation + stakingTotalAllocation == initialSupply);
    }
    
    modifier onlyGiveawayFund() {
        require(giveawayFunds[msg.sender].fundAddress == msg.sender, "Caller not a giveaway fund");
        _;
    }
    
    modifier onlyStakingFund() {
        require(stakingFunds[msg.sender].fundAddress == msg.sender, "Caller not a staking fund");
        _;
    }
    
    function developerFundClaimable() public view returns (uint) {
        //TODO safemath
        uint claimableInitially = (initialSupply / 10); // 10% of total supply
        uint claimableOverTime = developerFund.totalAllocated - claimableInitially; // 20% of total supply
        uint claimablePerSecond = (claimableOverTime / (365 days * 4)); //claimableOverTime / (seconds in 4 years)
        uint numSecondsElapsed = block.timestamp - inceptionTimestamp;
        uint totalClaimable = claimableInitially + (claimablePerSecond * numSecondsElapsed);
        return totalClaimable - developerFund.totalClaimed;
    }
    
    function developerFundClaim() external {
        uint toClaim = developerFundClaimable();
        require(toClaim > 0, "No amount to claim");
        developerFund.totalClaimed += toClaim; //TODO safemath
        resolvToken.transfer(developerFund.fundAddress, toClaim);
        //TODO emit event
    }
    
    function _addGiveawayFund(address _addr, uint _allocation) internal {
        require(_addr != address(0), "Fund is the zero address");
        require(_allocation > 0, "Allocation is zero");
        require((giveawayAllocationSoFar + _allocation) <= giveawayTotalAllocation, "Allocation exceeds maximum");
        giveawayAllocationSoFar += _allocation;
        giveawayFunds[_addr].fundAddress = _addr;
        giveawayFunds[_addr].totalAllocated += _allocation;
        resolvToken.increaseAllowance(_addr, _allocation);
    }
    
    function addGiveawayFund(address _addr, uint _allocation) external onlyOwner {
        _addGiveawayFund(_addr, _allocation);
    }
    
    function reportGiveawayClaimed(uint _amount) external onlyGiveawayFund {
        giveawayFunds[msg.sender].totalClaimed += _amount;
    }
    
    function _addStakingFund(address _addr, uint _allocation) internal {
        require(_addr != address(0), "Fund is the zero address");
        require(_allocation > 0, "Allocation is zero");
        require((stakingAllocationSoFar + _allocation) <= stakingTotalAllocation, "Allocation exceeds maximum");
        stakingAllocationSoFar += _allocation;
        stakingFunds[_addr].fundAddress = _addr;
        stakingFunds[_addr].totalAllocated += _allocation;
        resolvToken.increaseAllowance(_addr, _allocation);
    }
    
    function addStakingFund(address _addr, uint _allocation) external onlyOwner {
        _addStakingFund(_addr, _allocation);
    }
    
    function reportStakingRewardClaimed(uint _amount) external onlyStakingFund {
        stakingFunds[msg.sender].totalClaimed += _amount;
    }
    

}