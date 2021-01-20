// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;


import "github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol";

contract Stake_Test {
    using SafeMath for uint256;
    
    struct Stake {
        uint256 block;
        uint256 amount;
    }
    
    //  use openzeppelin alternatively
    address public owner;
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    uint8 public profitPerBlockPercentage;
    uint8 public feePercentage;
    
    uint256 public MIN_STAKE = 10e6;
    
    uint256 devFee;
    
    mapping(address => Stake) public stakeOf;
    mapping(address => uint256) public pendingProfitOf;
    
    event Received(address from, uint256 amount);
    event Staked(address from, uint256 amount);
    event Unstaked(address from, uint256 amount);
    
    
    constructor() {
        profitPerBlockPercentage = 1;
        feePercentage = 5;
    }
    
    /**
     * @dev Receives ETH from outside.
     */
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
    
    /**
     * @dev Updates profitPerBlockPercentage.
     * @param _perc Percentage to be used.
     */
    function updateProfitPerBlockPercentage(uint8 _perc) external onlyOwner {
        require(_perc <= 100, "Wrong perc");
        
        profitPerBlockPercentage = _perc;
    }
    
    /**
     * @dev Updates feePercentage.
     * @param _perc Percentage to be used.
     */
    function updateFeePercentage(uint8 _perc) external onlyOwner {
        require(_perc <= 100, "Wrong perc");
        
        feePercentage = _perc;
    }
    
    /**
     * @dev Withdraws dev fee.
     */
    function withdrawDevFee() external onlyOwner {
        require(devFee > 0, "No fee");
        
        uint256 toTransfer = devFee;
        delete devFee;
        
        msg.sender.transfer(toTransfer);
    }
    
    /**
     * @dev Destroys the contract.
     */
    function kill() external onlyOwner {
        selfdestruct(msg.sender);
    }
    
    /**
     * @dev Returns balance of current contract.
     * @return Balance.
     */
    function getBalance() public view returns(uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Calculates profit for address.
     * @return Profit amount.
     */
    function calculateProfit() public view returns(uint256) {
        if (stakeOf[msg.sender].block > 0) {
            uint256 blocks = block.number.sub(stakeOf[msg.sender].block);
            return stakeOf[msg.sender].amount.mul(blocks).mul(profitPerBlockPercentage).div(100);
        }
        return 0;
    }
    
    /**
     * @dev Makes stake.
     */
    function stake() payable external {
        require(msg.value >= MIN_STAKE, "Wrong stake");
        
        uint256 pendingProfit = calculateProfit();
        if (pendingProfit > 0) {
            pendingProfitOf[msg.sender] = pendingProfitOf[msg.sender].add(pendingProfit);
        }
        
        stakeOf[msg.sender].amount = stakeOf[msg.sender].amount.add(msg.value);
        stakeOf[msg.sender].block = block.number;
        
        emit Staked(msg.sender, msg.value);
    }
    
    /**
     * @dev Unstakes.
     * @param _amount Amount to unstake.
     */
    function unstake(uint256 _amount) external {
        Stake storage stakeObj = stakeOf[msg.sender];
        
        require(stakeObj.amount > 0, "No stake");
        require(stakeObj.amount <= _amount, "Wrong amount");
        
        uint256 profit = calculateProfit().add(pendingProfitOf[msg.sender]);
        uint256 fee = profit.mul(feePercentage).div(100);
        uint256 toTransfer = stakeObj.amount.add(profit).sub(fee);
        require(getBalance() >= toTransfer, "Not enough funds");
        
        stakeObj.amount = stakeObj.amount.sub(_amount);
        
        devFee = devFee.add(fee);
        msg.sender.transfer(toTransfer);
        
        emit Unstaked(msg.sender, toTransfer);
    }
}