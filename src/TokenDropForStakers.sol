// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract TokenDistributorForStakers is Ownable {
    error TokenInAddressCantBeZero();
    error TokenOutAddressCantBeZero();
    error AmountCantBeZero();
    error InsufficientBalance(uint256 balance, uint256 amount);
    error TransferFailed();
    error NotEnoughBalanceOnContract();
    error NotEnoughStakedTokens(uint256 amountStakedTokens, uint256 amount);
    error CooldownClaimNotReached(uint256 minTimeClaimTokens, uint256 timeLastClaimTokens);
    error NothingToClaim();
    error AmountStakedTokensEqualZero();

    event Staked(address staker, uint256 amount, uint256 timestamp);
    event Unstaked(address staker, uint256 amount, uint256 timestamp);

    uint256 public constant COOLDOWN = 7 days;

    struct Staker {
        address addr;
        uint256 amount;
        uint256 timestampLastClaim;
    }

    mapping(address => Staker) stakers;

    ERC20 public tokenOut;
    uint256 public constant MONEY_COFFICIENT = 5 * 10 ** 14;

    modifier initStaker() {
        if (stakers[msg.sender].addr == address(0)) {
            stakers[msg.sender].addr = msg.sender;
        }
        _;
    }

    constructor(address _tokenOut, address initialOwner) Ownable(initialOwner) {
        if (_tokenOut == address(0)) revert TokenOutAddressCantBeZero();
        tokenOut = ERC20(_tokenOut);
    }

    function stake() public payable initStaker {
        if (msg.value == 0) revert AmountCantBeZero();
        if (msg.sender.balance < msg.value) revert InsufficientBalance(msg.sender.balance, msg.value);
        stakers[msg.sender].amount += msg.value;

        emit Staked(msg.sender, msg.value, block.timestamp);
    }

    function unstake() public initStaker {
        if (stakers[msg.sender].amount == 0) revert AmountStakedTokensEqualZero();
        if (address(this).balance <= stakers[msg.sender].amount) revert NotEnoughBalanceOnContract();
        uint256 amount = stakers[msg.sender].amount;
        stakers[msg.sender].amount = 0;
        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();
        emit Unstaked(msg.sender, amount, block.timestamp);
    }

    function getTokens() public initStaker returns (bool) {
        if (stakers[msg.sender].timestampLastClaim > 0) {
            if (block.timestamp < stakers[msg.sender].timestampLastClaim + COOLDOWN) {
                revert CooldownClaimNotReached(
                    stakers[msg.sender].timestampLastClaim + COOLDOWN, stakers[msg.sender].timestampLastClaim
                );
            }
        }
        uint256 amountTokensToClaim = stakers[msg.sender].amount / MONEY_COFFICIENT;
        if (amountTokensToClaim == 0) {
            revert NothingToClaim();
        }
        if (tokenOut.balanceOf(address(this)) < amountTokensToClaim) revert NotEnoughBalanceOnContract();
        stakers[msg.sender].timestampLastClaim = block.timestamp;
        bool success = tokenOut.transfer(msg.sender, amountTokensToClaim);
        if (!success) revert TransferFailed();
        return true;
    }

    function withdraw(uint256 _amount) external onlyOwner {
        if (_amount == 0) revert AmountCantBeZero();
        if (address(this).balance < _amount) {
            revert InsufficientBalance(address(this).balance, _amount);
        }
        (bool success,) = payable(owner()).call{value: _amount}("");
        if (!success) revert TransferFailed();
    }

    function getContractBalanceTokenOut() external view onlyOwner returns (uint256) {
        return tokenOut.balanceOf(address(this));
    }

    function getStaker() external initStaker returns (address, uint256, uint256) {
        return (stakers[msg.sender].addr, stakers[msg.sender].amount, stakers[msg.sender].timestampLastClaim);
    }
}
