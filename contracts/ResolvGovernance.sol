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
    
    struct DeveloperFund {
        address fundAddress;
        uint totalAllocated;
        uint totalClaimed;
    }
    
    DeveloperFund internal developerFund;
    
    constructor() {
        inceptionBlock = block.number;
        inceptionTimestamp = block.timestamp;
        resolvToken = new ResolvToken(initialSupply);
        
        uint defaultPrice = 10 ether;
        uint costPerBlock = 1e15;
        resolvApp = new ResolvApp(defaultPrice, costPerBlock, address(resolvToken));
        // TODO set owner or admin
        
        developerFund = DeveloperFund(owner(), (initialSupply / 10) * 3, 0);
        
    }
    
    function developerFundClaimable() public view returns (uint) {
        //TODO safemath
        uint claimableInitially = (initialSupply / 10); // 10% of total supply
        uint claimableOverTime = developerFund.totalAllocated - claimableInitially; // 20% of total supply
        uint claimablePerSecond = (claimableOverTime / (365 days * 3)); //claimableOverTime / (seconds in 3 years)
        uint numSecondsElapsed = block.timestamp - inceptionTimestamp;
        uint totalClaimable = claimableInitially + (claimablePerSecond * numSecondsElapsed);
        return totalClaimable - developerFund.totalClaimed;
    }
    
    function developerFundClaim() public {
        uint toClaim = developerFundClaimable();
        developerFund.totalClaimed += toClaim;
        resolvToken.transfer(developerFund.fundAddress, toClaim);
    }
    
}