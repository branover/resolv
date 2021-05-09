// contracts/resolv.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.0 <0.9.0;

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
    DistributionFund[] public giveawayFunds;
    DistributionFund[] public stakingFunds;
    uint public giveawayAllocation;
    uint public stakingAllocation;
    
    
    constructor() {
        inceptionBlock = block.number;
        inceptionTimestamp = block.timestamp;
        resolvToken = new ResolvToken(initialSupply);
        
        uint defaultPrice = 10 ether;
        uint costPerBlock = 1e15;
        resolvApp = new ResolvApp(defaultPrice, costPerBlock, address(resolvToken));
        // TODO set owner or admin
        
        developerFund = DistributionFund(owner(), (initialSupply / 10) * 3, 0); // 30% allocated to developer fund, 10% initially, another 20% vested over 4 years
        giveawayAllocation = (initialSupply / 10) * 2; // 20% allocated to giveaway funds
        stakingAllocation = (initialSupply / 10) * 5; // 50% allocated to staking funds
        assert(developerFund.totalAllocated + giveawayAllocation + stakingAllocation == initialSupply);
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
        uint giveawayAllocationSoFar = 0;
        for (uint i = 0; i < giveawayFunds.length; i++) {
            giveawayAllocationSoFar += giveawayFunds[i].totalAllocated;
        }
        //TODO safemath
        require((giveawayAllocationSoFar + _allocation) <= giveawayAllocation, "Giveaway can't be allocated this much");
        giveawayFunds.push(DistributionFund(_addr, _allocation, 0));
        resolvToken.approve(_addr, _allocation);
    }
    
    function addGiveawayFund(address _addr, uint _allocation) external onlyOwner {
        _addGiveawayFund(_addr, _allocation);
    }
    
    function _addStakingFund(address _addr, uint _allocation) internal {
        require(_addr != address(0), "Fund is the zero address");
        require(_allocation > 0, "Allocation is zero");
        uint stakingAllocationSoFar = 0;
        for (uint i = 0; i < stakingFunds.length; i++) {
            stakingAllocationSoFar += stakingFunds[i].totalAllocated;
        }
        //TODO safemath
        require((stakingAllocationSoFar + _allocation) <= stakingAllocation, "Staking fund can't be allocated this much");
        stakingFunds.push(DistributionFund(_addr, _allocation, 0));
        resolvToken.approve(_addr, _allocation);
    }
    
    function addStakingFund(address _addr, uint _allocation) external onlyOwner {
        _addStakingFund(_addr, _allocation);
    }
    

}