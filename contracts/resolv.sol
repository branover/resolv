
// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.0 <0.9.0;


contract Resolv {
	mapping (address => UserStruct) private addressToUser;
	mapping (string => address) private usernameToAddress;
	uint public defaultPrice;
	uint public costPerBlock;
	CheckPoint[] private costPerBlockCheckpoints;
	
	
	struct UserStruct {
	    string username;
	    string name;
	    string email;
	    uint16 telephoneNumber;
	    uint price;
	    uint balance;
	    uint lastTransfer;
	    uint lastDeposit;
	    bool exists;
	}
	
	struct CheckPoint {
	    uint block;
	    uint value;
	}
	
	event CedeEvent(address _from, string username);
	event RegisterUsernameEvent(address _from, string username);
	event TransferUsernameEvent(address _from, address _to, string username);
	event SellUsernameEvent(address _from, address _to, string username, uint price);

	constructor() {
	    _setDefaultPrice(100000);
	    _setCostPerBlock(10);
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
	    require(usernameToAddress[_username] ==  address(0x0), "Username already taken");
	    UserStruct memory newUser = UserStruct(_username, "", "", 0, defaultPrice, 0, block.number, block.number, true);
	    addressToUser[msg.sender] = newUser;
	    usernameToAddress[_username] = msg.sender;
	    emit RegisterUsernameEvent(msg.sender, _username);
	}
	
	function getUsername(address _addr) external view hasUsername(_addr) returns (UserStruct memory) {
	    //TODO Do we want to return the whole struct?  Some of it needs to be processed, not usable in raw form (like price and balance)
	    return addressToUser[_addr];
	}
	
	function getAddress(string memory _username) external view returns (address) {
	    require(usernameToAddress[_username] != address(0x0), "Username has no associated address");
	    return usernameToAddress[_username];
	}
	
	function cedeUsername() external hasUsername(msg.sender) {
	    string memory username = addressToUser[msg.sender].username;
	    delete usernameToAddress[username];
	    delete addressToUser[msg.sender];
	    emit CedeEvent(msg.sender, username);
	}
	
	function transferUsername(address _to) external {
	    _transferUsername(msg.sender, _to);
	}
	
	function buyUsername(string memory _username) external {
	    //TODO Implement
	    //TODO Burn part of the cost
	}
	
	
	function _transferUsername(address _from, address _to) private hasUsername(_from) hasNoUsername(_to) {
	    _withdrawBalance(_from);	    
	    
	    UserStruct memory user = addressToUser[_from];
	    user = UserStruct(user.username, "", "", 0, defaultPrice, 0, block.number, block.number, true);
	    addressToUser[_to] = user;
	    usernameToAddress[user.username] = _to;
	    
	    delete addressToUser[_from];
	    emit TransferUsernameEvent(_from, _to, user.username);
	}
	
	function _setDefaultPrice(uint _price) private {
	    defaultPrice = _price;
	}
	
	function _setCostPerBlock(uint _cost) private {
	    costPerBlockCheckpoints.push(CheckPoint(block.number, _cost));
	    costPerBlock = _cost;
	}

    function setPrice(uint _price) external hasUsername(msg.sender) {
        UserStruct storage user = addressToUser[msg.sender];
        require(hasPositiveBalance(msg.sender) || _price <= defaultPrice, "Can't set the price above the default unless you have a positive balance");
        // TODO If balance becomes 0 and price is above default, need to readjust to default
        user.price = _price;
    }
    
    function _withdrawBalance(address _from) private hasUsername(_from) {
        UserStruct storage user = addressToUser[msg.sender];
        // TODO Calculate fees and burn/distribute them
        uint balance = getBalance(_from);
        require(balance > 0, "User doesn't have a positive balance");
        // TODO Refund ERC-20 balance
        user.balance = 0;
    }
    
    function withdrawBalance() public {
        _withdrawBalance(msg.sender);
    }
    
    function _depositBalance(address _to, uint amount) private hasUsername(_to) {
        // TODO verify user has amount of ERC-20 token
        // TODO reduce ERC-20 token balance by amount
        // TODO Calculate fees and burn/distribute them
        UserStruct storage user = addressToUser[_to];
        user.balance = getBalance(_to) + amount; // TODO Safemath
        user.lastDeposit = block.number;
        
    }
    
    function depositBalance(uint amount) external {
        _depositBalance(msg.sender, amount);
    }
    
    function _calculateFees(uint _lastDeposit) private view returns (uint) {
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
    
    function getBalance(address _addr) public view hasUsername(_addr) returns (uint) {
        UserStruct memory user = addressToUser[_addr];
        uint owedFees = _calculateFees(user.lastDeposit);       
        int remaining = int(user.balance) - int(owedFees);      // TODO Safemath
        if (remaining > 0) {
            return uint(remaining);
        }
        else {
            return 0;
        }
    }
    
    function hasPositiveBalance(address _addr) public view returns (bool) {
	    return getBalance(_addr) > 0;
	}
	
}