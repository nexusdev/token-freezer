import 'erc20/erc20.sol';

contract Freezer {
    uint last_id;

    struct Entry {
        address owner;
        address token;
        uint release_timestamp;
        uint amount;
    }

    function getEntry(uint id)
        constant returns (address, address, uint, uint)
    {
        var entry = _entries[id];
        return (entry.owner, entry.token,
                entry.release_timestamp, entry.amount);
    }

    mapping( uint => Entry ) _entries;

    function freeze(uint duration, address token) returns (uint) {
        return freeze(duration, token,
                      ERC20(token).allowance(msg.sender, this));
    }

    function freeze(uint duration, address token, uint quantity)
        returns (uint id)
    {

        ERC20(token).transferFrom(msg.sender, this, quantity);
        id = last_id++;
        _entries[id].owner = msg.sender;
        _entries[id].amount += quantity;
        _entries[id].release_timestamp = currentTimestamp() + duration;
        _entries[id].token = token;
    }

    function unfreeze(uint id) {
        var entry = _entries[id];
        if(msg.sender != entry.owner)  {
            throw;
        }
        if(currentTimestamp() < entry.release_timestamp) {
            throw;
        }
        ERC20(entry.token).transfer(msg.sender, entry.amount);
    }

    function currentTimestamp() internal constant returns (uint) {
        return block.timestamp;
    }

    function () {
        throw;
    }
}
