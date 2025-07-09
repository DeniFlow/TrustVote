// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "node_modules/@openzeppelin/contracts/access/Ownable.sol";

contract TokenDistributorForStakers is Ownable {
    error TokenInAddressCantBeZero();
    error TokenOutAddressCantBeZero();
    error AmountCantBeZero(uint256 amount);
    error InsufficientBalance(uint256 balance, uint256 amount);
    error TransferFailed();
    error NotEnoughBalanceOnContract();
    error NotEnoughStakedTokens(uint256 amountStakedTokens, uint256 amount);
    error CooldownClaimNotReached(uint256 minTimeClaimTokens, uint256 timeLastClaimTokens);
    error NotEnoughToClaim(uint256 minAmountTokensToClaim, uint256 amountTokensToClaim);

    event Staked(address staker, uint256 amount, uint256 timestamp);
    event Unstaked(address staker, uint256 amount, uint256 timestamp);

    uint256 public constant COOLDOWN = 7 days;

    struct Staker {
        address addr;
        uint256 amount;
        uint256 timestampStake;
        uint256 timestampLastClaim;
    }

    mapping(address => Staker) stakers;

    ERC20 public tokenIn;
    ERC20 public tokenOut;
    uint256 public constant MONEY_COFFICIENT = 10e6;
    uint256 public constant TIME_COFFICIENT = 7 days;

    constructor(address _tokenIn, address _tokenOut) Ownable(msg.sender) {
        if (_tokenIn == address(0)) revert TokenInAddressCantBeZero();
        if (_tokenOut == address(0)) revert TokenOutAddressCantBeZero();
        tokenIn = ERC20(_tokenIn);
        tokenOut = ERC20(_tokenOut);
    }

    function stake(uint256 _amount) public {
        if (_amount == 0) revert AmountCantBeZero(_amount);
        if (tokenIn.balanceOf(msg.sender) < _amount) revert InsufficientBalance(tokenIn.balanceOf(msg.sender), _amount);
        stakers[msg.sender].amount += _amount;
        if (stakers[msg.sender].timestampStake == 0) {
            stakers[msg.sender].timestampStake = block.timestamp;
        }
        bool success = tokenIn.transfer(address(this), _amount);
        if (!success) revert TransferFailed();

        emit Staked(msg.sender, _amount, block.timestamp);
    }

    function unstake(uint256 _amount) public {
        if (_amount == 0) revert AmountCantBeZero(_amount);
        if (stakers[msg.sender].amount < _amount) revert NotEnoughStakedTokens(stakers[msg.sender].amount, _amount);
        if (tokenIn.balanceOf(address(this)) <= _amount) revert NotEnoughBalanceOnContract();
        stakers[msg.sender].amount -= _amount;
        if (stakers[msg.sender].amount == 0) {
            stakers[msg.sender].timestampStake = 0;
        }
        bool success = tokenIn.transfer(msg.sender, _amount);
        if (!success) revert TransferFailed();
        emit Unstaked(msg.sender, _amount, block.timestamp);
    }

    function getTokens() public returns (bool) {
        if (block.timestamp < stakers[msg.sender].timestampLastClaim + COOLDOWN) {
            revert CooldownClaimNotReached(
                stakers[msg.sender].timestampLastClaim + COOLDOWN, stakers[msg.sender].timestampLastClaim
            );
        }
        uint256 amountTokensToClaim = stakers[msg.sender].amount / MONEY_COFFICIENT
            + (block.timestamp - stakers[msg.sender].timestampLastClaim) / COOLDOWN;
        if (amountTokensToClaim < tokenOut.decimals()) revert NotEnoughToClaim(tokenOut.decimals(),amountTokensToClaim);
        if (tokenOut.balanceOf(address(this)) < amountTokensToClaim) revert NotEnoughBalanceOnContract();
        stakers[msg.sender].timestampLastClaim = block.timestamp;
        bool success = tokenOut.transfer(msg.sender,amountTokensToClaim);
        if (!success) revert TransferFailed();
        return true;
    }

    function withdraw(uint256 _amount) external onlyOwner {
        if (_amount == 0) revert AmountCantBeZero(_amount);
        if (tokenIn.balanceOf(address(this)) < _amount) {
            revert InsufficientBalance(tokenIn.balanceOf(address(this)), _amount);
        }
        bool success = tokenIn.transfer(owner(), _amount);
        if (!success) revert TransferFailed();
    }
}
