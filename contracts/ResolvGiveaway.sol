// contracts/ResolvGiveaway.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./ResolvGovernance.sol";

contract ResolvGiveaway is Ownable {
    mapping (address => uint) internal claimed;
    IERC20 internal resolvToken;
    address internal resolvGovernance;

    bool public active;
    uint public claimablePerAddress;
    uint public totalClaimed;
    uint public totalAllocated;
    
    constructor(address _resolvToken, address _resolvGovernance, uint _claimablePerAddress, uint _totalAllocated) {
        resolvToken = IERC20(_resolvToken);
        claimablePerAddress = _claimablePerAddress;
        resolvGovernance = _resolvGovernance;
        totalAllocated = _totalAllocated;
    }
    
    function setActive(bool _active) external onlyOwner {
        active = _active;
    }
    
    function setGiveawayAmount(uint _claimablePerAddress, uint _totalAllocated) external onlyOwner {
        claimablePerAddress = _claimablePerAddress;
        totalAllocated = _totalAllocated;
    }
    
    function getClaimable(address _addr) public view returns (uint) {
        return Math.min(claimablePerAddress - claimed[_addr], totalAllocated - totalClaimed);
    }
    
    function claim() external {
        require(active, "Giveaway is not active");
        require(claimed[msg.sender] < claimablePerAddress, "Can't claim any more");
        uint toClaim = getClaimable(msg.sender);
        require(toClaim > 0, "Can't claim any more");
        totalClaimed += toClaim;
        claimed[msg.sender] = claimablePerAddress;
        resolvToken.transferFrom(resolvGovernance, msg.sender, toClaim);
    }
    
}

