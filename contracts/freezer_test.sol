import 'dapple/test.sol';

import 'erc20/erc20.sol';

import 'freezer.sol';

contract TestableFreezer is Freezer {
    uint public debug_timestamp;

    function currentTimestamp() internal constant returns (uint) {
        return debug_timestamp;
    }

    function setTimestamp(uint timestamp) {
        debug_timestamp = timestamp;
    }
}

contract MockToken is ERC20 {
    // Not to be used in the wild! This is insecure code. It also does
    // not conform fully to the ERC20 spec (i.e., it emits no events).
    // For a good ERC20 implementation, please consult the DSTokenBase
    // contract in Dappsys. (https://github.com/nexusdev/dappsys)

    mapping(address=>uint) balances;
    mapping(address=>mapping(address=>uint)) allowances;
    uint _totalSupply;

    function MockToken(uint supply) {
        _totalSupply = supply;
        balances[this] = supply;
    }

    function totalSupply() constant returns (uint) {
        return _totalSupply;
    }

    function balanceOf(address who) constant returns (uint) {
        return balances[who];
    }

    function allowance(address owner, address spender)
        constant returns (uint)
    {
        return allowances[owner][spender];
    }

    function transfer(address to, uint value) returns (bool ok) {
        return transferFrom(msg.sender, to, value);
    }

    function transferFrom(address from, address to, uint value)
        returns (bool ok)
    {
        if ((from != msg.sender &&
             allowances[from][msg.sender] < value) ||
            balances[from] < value)
        {
            throw;
        }
        balances[from] -= value;
        balances[to] += value;
        return true;
    }

    function approve(address spender, uint value)
        returns (bool ok)
    {
        allowances[msg.sender][spender] = value;
    }

    // Non-ERC20 functions
    function endow(address target, uint value) {
        balances[this] -= value;
        balances[target] += value;
    }
}

contract AddressContract {}

contract FreezerTest is Test {
    uint constant TOKEN_SUPPLY = 1000;
    uint constant FREEZE_AMOUNT = 10;
    uint constant FREEZE_DURATION = 24 hours;

    address recipient;
    TestableFreezer freezer;
    MockToken token;

    function setUp() {
        freezer = new TestableFreezer();
        freezer.setTimestamp(block.timestamp);
        recipient = address(new AddressContract());
        token = new MockToken(TOKEN_SUPPLY);
        token.endow(this, FREEZE_AMOUNT);
    }

    function testFailWithoutAllowance() {
        freezer.freeze(FREEZE_DURATION, token, FREEZE_AMOUNT);
    }

    function testFreeze() {
        token.approve(freezer, FREEZE_AMOUNT);
        freezer.freeze(FREEZE_DURATION, token, FREEZE_AMOUNT);
        assertEq(token.balanceOf(this), 0);
        assertEq(token.balanceOf(freezer), FREEZE_AMOUNT);
    }

    function testGetEntry() {
        token.approve(freezer, FREEZE_AMOUNT);
        var freeze_id = freezer.freeze(FREEZE_DURATION, token, FREEZE_AMOUNT);
        var (owner, _token, release, amount) = freezer.getEntry(freeze_id);
        assertEq(owner, this);
        assertEq(token, _token);
        assertEq(release, freezer.debug_timestamp() + FREEZE_DURATION);
        assertEq(amount, FREEZE_AMOUNT);
    }

    function testFailEarlyUnfreeze() {
        token.approve(freezer, FREEZE_AMOUNT);
        var freeze_id = freezer.freeze(FREEZE_DURATION, token, FREEZE_AMOUNT);
        freezer.unfreeze(freeze_id);
    }

    function testUnfreeze() {
        token.approve(freezer, FREEZE_AMOUNT);
        var freeze_id = freezer.freeze(FREEZE_DURATION, token, FREEZE_AMOUNT);
        freezer.setTimestamp(block.timestamp + FREEZE_DURATION);
        freezer.unfreeze(freeze_id);
        assertEq(token.balanceOf(freezer), 0);
        assertEq(token.balanceOf(this), FREEZE_AMOUNT);
    }

    function testSendingEther() {
        var old_balance = this.balance;
        address(freezer).send(1);
        assertEq(address(freezer).balance, 0);
        assertEq(old_balance, this.balance);
    }
}
