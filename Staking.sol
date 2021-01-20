// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./Token.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

/**
 * @notice ETH only
 */
contract PMCStaking {
  using SafeMath for uint256;

  address public Token;
  
  struct StateForIncome {
    uint256 income;
    uint256 stakesTotal;
  }

  bool private stakesStarted;
  uint256 public stakesTotal;
  StateForIncome[] private incomes;

  mapping(address => uint256) public incomeIdxToStartCalculatingRewardOf;
  mapping(address => uint256) public pendingRewardOf;
  mapping(address => uint256) public stakeOf;
  
  /**
   * @dev Constructor.
   * @param _Token Token token address.
   */
  constructor(address _Token) {
    require(_Token != address(0), "Wrong Token");
    Token = _Token;
  }

  /**
   * @dev Adds ETH to reward pool.
   * @param _amount ETH amount.
   */
  function replenishRewardPool(uint256 _amount) internal {
    require(_amount > 0, "Wrong replenish amnt");
    incomes.push(StateForIncome(_amount, stakesTotal));
  }

  /**
   * @dev Stakes Token tokens.
   * @param _tokens Token amount.
   */
  function stake(uint256 _tokens) external {
    require(_tokens > 0, "0 tokens");
    ERC20(Token).transferFrom(msg.sender, address(this), _tokens);
    
    if (stakeOf[msg.sender] == 0) {
      if (!stakesStarted) {
        stakesStarted = true;
        incomeIdxToStartCalculatingRewardOf[msg.sender] = 0;
      } else {
        incomeIdxToStartCalculatingRewardOf[msg.sender] = incomes.length;
      }
    } else {
      uint256 reward;
      uint256 _incomeIdxToStartCalculatingRewardOf;
      (reward, _incomeIdxToStartCalculatingRewardOf) = calculateReward(0);
      
      pendingRewardOf[msg.sender] = pendingRewardOf[msg.sender].add(reward);
      incomeIdxToStartCalculatingRewardOf[msg.sender] = _incomeIdxToStartCalculatingRewardOf;
    }

    stakeOf[msg.sender] = stakeOf[msg.sender].add(_tokens);
    stakesTotal = stakesTotal.add(_tokens);
  }

  /**
   * @dev Unstakes Token tokens.
   * @param _tokens Token amount.
   */
  function unstake(uint256 _tokens) external {
    require(_tokens > 0, "Wrong tokens");
    require(_tokens <= stakeOf[msg.sender], "Not enough tokens");
    withdrawReward(0);

    stakeOf[msg.sender] = stakeOf[msg.sender].sub(_tokens);
    stakesTotal = stakesTotal.sub(_tokens);
    
    ERC20(Token).transfer(msg.sender, _tokens);
  }

  /**
   * @dev Withdraws staking reward.
   * @param _maxLoop Max loop. Used as a safeguard for block gas limit.
   */
  function withdrawReward(uint256 _maxLoop) public {
    uint256 reward;
    uint256 _incomeIdxToStartCalculatingRewardOf;
    (reward, _incomeIdxToStartCalculatingRewardOf) = calculateReward(_maxLoop);

    incomeIdxToStartCalculatingRewardOf[msg.sender] = _incomeIdxToStartCalculatingRewardOf;
    if (pendingRewardOf[msg.sender] > 0) {
      reward.add(pendingRewardOf[msg.sender]);
      delete pendingRewardOf[msg.sender];
    }

    msg.sender.transfer(reward);
  }

  /**
   * @dev Calculates staking reward.
   * @param _maxLoop Max loop. Used as a safeguard for block gas limit.
   */
  function calculateReward(uint256 _maxLoop) public view returns(uint256 reward, uint256 _incomeIdxToStartCalculatingRewardOf) {
    require(stakeOf[msg.sender] > 0, "No stake");

    uint256 incomesLength = incomes.length;
    require(incomesLength > 0, "No incomes");

    uint256 startIdx = incomeIdxToStartCalculatingRewardOf[msg.sender];
    require(startIdx < incomesLength, "Nothing to calculate");

    uint256 incomesToCalculate = incomesLength.sub(startIdx);
    uint256 stopIdx = ((_maxLoop > 0 && _maxLoop < incomesToCalculate)) ? startIdx.add(_maxLoop).sub(1) : startIdx.add(incomesToCalculate).sub(1);

    for (uint256 i = startIdx; i <= stopIdx; i++) {
      StateForIncome memory incomeTmp = incomes[i];
      uint256 incomeReward = incomeTmp.income.mul(stakeOf[msg.sender]).div(incomeTmp.stakesTotal);
      reward = reward.add(incomeReward);
    }

    _incomeIdxToStartCalculatingRewardOf = stopIdx.add(1);
  }
}