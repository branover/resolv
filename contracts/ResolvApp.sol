// contracts/resolv.sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IERC20Burnable.sol";

uint256 constant MAX_INT = 2**256 - 1;

contract ResolvApp is Ownable{
	mapping (address => UserAccount) internal addressToUser;
	mapping (string => address) internal usernameToAddress;
	mapping (string => ContactCard) internal usernameToContactCard;
	mapping (address => uint) internal withdrawableBalance;
	
	uint public defaultPrice;
	uint public costPerBlock;
	uint public burnableFees;

	CheckPoint[] internal costPerBlockCheckpoints;
	
	IERC20Burnable resolvToken;
	
	struct UserAccount {
	    string username;
	    uint preferredPrice;
	    uint balance;
	    uint lastTransfer;
	    uint lastDeposit;
	    bool verified;
	    bool exists;
	}
	
	struct ContactCard {
	    string name;
	    string email;
	    uint16 telephoneNumber;
	}
	
	struct CheckPoint {
	    uint block;
	    uint value;
	}
	
	event CedeEvent(address _from, string username);
	event RegisterUsernameEvent(address _from, string username);
	event TransferUsernameEvent(address _from, address _to, string username);
	event SellUsernameEvent(address _from, address _to, string username, uint price);
	event CostPerBlockSet(uint _cost);
	event DefaultPriceSet(uint _price);

	constructor(uint _defaultPrice, uint _costPerBlock, address _resolvTokenAddress) {
	    _setDefaultPrice(_defaultPrice);
	    _setCostPerBlock(_costPerBlock);
	    resolvToken = IERC20Burnable(_resolvTokenAddress);
	}
	
	modifier hasUsername(address _addr) {
	    require(addressToUser[_addr].exists, "Address has no username");
	    _;
	}
	
	modifier hasNoUsername(address _addr) {
	    require(!addressToUser[_addr].exists, "Address already has username");
	    _;
	}
	
	
	function registerUsername(string memory _username) external hasNoUsername(msg.sender) {
	    // TODO consider allowing a hash of the username to be requested first to prevent frontrunning
	    require(usernameToAddress[_username] ==  address(0x0), "Username already taken");
	    require(bytes(_username).length < 64, "Username must be less than 64 bytes");

	    UserAccount memory newUser = UserAccount(_username, MAX_INT, 0, block.number, block.number, false, true);
	    addressToUser[msg.sender] = newUser;
	    usernameToAddress[_username] = msg.sender;
	    emit RegisterUsernameEvent(msg.sender, _username);
	}
	
	function setContactCard(string memory _name, string memory _email, uint16 _telephoneNumber) external hasUsername(msg.sender) {
	    UserAccount storage user = addressToUser[msg.sender];
	    ContactCard memory newContactCard = ContactCard(_name, _email, _telephoneNumber);
	    usernameToContactCard[user.username] = newContactCard;
	    // TODO Maybe emit event?
	}
	
	function getUserAccount(address _addr) external view hasUsername(_addr) returns (UserAccount memory, ContactCard memory) {
	    UserAccount memory userRaw = addressToUser[_addr];
	    userRaw.preferredPrice = getEffectivePrice(_addr);
	    (userRaw.balance,) = getBalance(_addr);
	    
	    ContactCard memory contactCard = usernameToContactCard[userRaw.username];
	    return (userRaw, contactCard);
	}
	
	function getAddress(string memory _username) external view returns (address) {
	    require(usernameToAddress[_username] != address(0x0), "Username has no associated address");
	    return usernameToAddress[_username];
	}
	
	function cedeUsername() external hasUsername(msg.sender) {
	    _addWithdrawableBalance(msg.sender); 
	    string memory username = addressToUser[msg.sender].username;
	    delete usernameToAddress[username];
	    delete addressToUser[msg.sender];
	    delete usernameToContactCard[username];
	    emit CedeEvent(msg.sender, username);
	}
	
	function transferUsername(address _to) external {
	    _transferUsername(msg.sender, _to);
	}
	
	function buyUsername(string memory _username) external hasNoUsername(msg.sender) {
	    // TODO consider allowing a hash of the username to be requested first to prevent frontrunning
	    address prevOwner = usernameToAddress[_username];
	    uint price = getEffectivePrice(prevOwner);
	    if (price == 0) {
	        _transferUsername(prevOwner, msg.sender);
	        return;
	    }
	    require(resolvToken.transferFrom(msg.sender, prevOwner, price), "RSLV transfer failed during buy");
	    // TODO Burn part of the cost
	    _transferUsername(prevOwner, msg.sender);
	    emit SellUsernameEvent(prevOwner, msg.sender, _username, price);
	}
	
	
	function _transferUsername(address _from, address _to) internal hasUsername(_from) hasNoUsername(_to) {
	    _addWithdrawableBalance(_from);	    
	    
	    UserAccount memory user = addressToUser[_from];
	    user = UserAccount(user.username, MAX_INT, 0, block.number, block.number, false, true);
	    addressToUser[_to] = user;
	    usernameToAddress[user.username] = _to;
	    
	    delete addressToUser[_from];
	    delete usernameToContactCard[user.username];
	    emit TransferUsernameEvent(_from, _to, user.username);
	}
	
	function _setDefaultPrice(uint _price) internal {
	    // TODO prevent griefers from being able to set something like MAX_INT as the default price
	    defaultPrice = _price;
	    emit DefaultPriceSet(_price);
	}
	
	function _setCostPerBlock(uint _cost) internal {
	    // TODO prevent griefers from being able to set something like MAX_INT as the cost per block
	    costPerBlockCheckpoints.push(CheckPoint(block.number, _cost));
	    costPerBlock = _cost;
	    emit CostPerBlockSet(_cost);
	}

    function setPreferredPrice(uint _price) external hasUsername(msg.sender) {
        addressToUser[msg.sender].preferredPrice = _price;
    }
    
    function setVerified(address _addr, bool _verified) public hasUsername(_addr) onlyOwner {
        addressToUser[_addr].verified = _verified;
    }
    
    function getEffectivePrice(address _addr) public view hasUsername(_addr) returns (uint) {
        UserAccount memory user = addressToUser[_addr];
        if(hasPositiveBalance(_addr) || user.preferredPrice <= defaultPrice || user.verified) {
            return user.preferredPrice;
        }
        return defaultPrice;
    }
    
    function _withdrawBalance(address _from) internal {
        uint withdrawAmount = withdrawableBalance[_from];
        require(withdrawAmount > 0, "Address doesn't have anything to withdraw");
        withdrawableBalance[_from] = 0;
        require(resolvToken.transferFrom(address(this), _from, withdrawAmount), "RSLV transfer failed during withdraw");
    }
    
    function _addWithdrawableBalance(address _from) internal hasUsername(_from) {
        (uint balance, uint fees) = getBalance(_from);
        UserAccount storage user = addressToUser[msg.sender];

        _collectFees(fees);
        
        withdrawableBalance[_from] += balance;
        user.balance = 0;
    }
    
    function withdrawBalance() external {
        if (addressToUser[msg.sender].exists) {
            _addWithdrawableBalance(msg.sender);
        }
        _withdrawBalance(msg.sender);
    }
    
    function _depositBalance(address _to, uint _amount) internal hasUsername(_to) {
        resolvToken.transferFrom(_to, address(this), _amount);
        UserAccount storage user = addressToUser[_to];
        uint feesTaken = 0;
        (user.balance, feesTaken) = getBalance(_to);
        _collectFees(feesTaken);
        user.balance += _amount; // TODO Safemath
        user.lastDeposit = block.number;
    }
    
    function depositBalance(address _to, uint amount) external {
        _depositBalance(_to, amount);
    }
    
    function getBalance(address _addr) public view hasUsername(_addr) returns (uint, uint ) {
        UserAccount memory user = addressToUser[_addr];
        uint owedFees = _calculateFees(user.lastDeposit);       
        int remaining = int(user.balance) - int(owedFees);      // TODO Safemath
        if (remaining > 0) {
            // Return how must is left after fees and the amount paid in fees
            return (uint(remaining), owedFees);
        }
        else {
            // If the fees exceed their balance, return a balance of 0 and their balance as fees paid
            return (0, user.balance);
        }
    }
    
    function hasPositiveBalance(address _addr) public view returns (bool) {
        (uint balance,) = getBalance(_addr);
	    return balance > 0;
	}
    
    function _calculateFees(uint _lastDeposit) internal view returns (uint) {
        uint fees = 0;
        //TODO Safemath
        for(uint i = 0; i < costPerBlockCheckpoints.length; i++) {
            if (_lastDeposit >= costPerBlockCheckpoints[i].block) {
                continue;
            }
            // Add the fees for the partial checkpoint where the _lastDeposit took place
            if (fees == 0) {
                fees += (costPerBlockCheckpoints[i].block - _lastDeposit) * costPerBlockCheckpoints[i-1].value;
                continue;
            }
            // Add the fees for a full checkpoint
            fees += (costPerBlockCheckpoints[i].block - costPerBlockCheckpoints[i-1].block) * costPerBlockCheckpoints[i-1].value;
        }
        
        uint lastCheckpoint = costPerBlockCheckpoints[costPerBlockCheckpoints.length-1].block;
        // Add the fees between the current block and the last checkpoint or the last deposit.
        if (_lastDeposit < lastCheckpoint) {
            fees += (block.number - lastCheckpoint) * costPerBlock;
        }
        else {
            fees += (block.number - _lastDeposit) * costPerBlock;
        }
        
        return fees;
    }
    
    function _collectFees(uint _fees) internal {
        //TODO Safemath
        burnableFees += _fees;
    }
    
    function burnFees() public {
        require(burnableFees > 0, "No fees to burn");
        resolvToken.burn(burnableFees);
        burnableFees = 0;
    }
    
	
}