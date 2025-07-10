// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "src/TokenDropForStakers.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MTK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TokenDistributorForStakersTest is Test {
    TokenDistributorForStakers distributor;
    MockERC20 token;
    address owner = address(0xABCD);
    address staker = address(0xBEEF);

    function setUp() public {
        vm.prank(owner);
        token = new MockERC20();
        vm.prank(owner);
        distributor = new TokenDistributorForStakers(address(token), owner);
        // Fund contract with tokens for claims
        token.mint(address(distributor), 1e24);
        // Fund staker and contract with ETH
        vm.deal(staker, 10 ether);
        vm.deal(address(distributor), 5 ether);
    }

    function testStakeZeroReverts() public {
        vm.prank(staker);
        vm.expectRevert(abi.encodeWithSelector(TokenDistributorForStakers.AmountCantBeZero.selector, 0));
        distributor.stake{value: 0}();
    }

    function testStakeIncreasesBalanceAndEmits() public {
        vm.prank(staker);
        vm.expectEmit(true, true, false, true);
        emit TokenDistributorForStakers.Staked(staker, 1 ether, block.timestamp);
        distributor.stake{value: 1 ether}();
        vm.prank(staker);
        (, uint256 amt,) = distributor.getStaker();
        assertEq(amt, 1 ether);
    }

    function testUnstakeZeroReverts() public {
        vm.prank(staker);
        vm.expectRevert(TokenDistributorForStakers.AmountStakedTokensEqualZero.selector);
        distributor.unstake();
    }

    function testUnstakeInsufficientContractBalanceReverts() public {
        vm.prank(staker);
        distributor.stake{value: 3 ether}();
        // withdraw contract's ETH to leave insufficient
        vm.prank(owner);
        distributor.withdraw(5 ether);
        vm.prank(staker);
        vm.expectRevert(TokenDistributorForStakers.NotEnoughBalanceOnContract.selector);
        distributor.unstake();
    }

    function testUnstakeSuccess() public {
        vm.prank(staker);
        distributor.stake{value: 2 ether}();
        uint256 pre = address(staker).balance;
        vm.prank(staker);
        vm.expectEmit(true, true, false, true);
        emit TokenDistributorForStakers.Unstaked(staker, 2 ether, block.timestamp);
        distributor.unstake();
        assertEq(address(staker).balance, pre + 2 ether);
        vm.prank(staker);
        (, uint256 amt,) = distributor.getStaker();
        assertEq(amt, 0);
    }

    function testCooldownClaimNotReachedReverts() public {
        vm.startPrank(staker);
        distributor.stake{value: 5 ether}();

        bool success = distributor.getTokens();
        assertTrue(success);

        (,, uint256 lastClaim) = distributor.getStaker();
        uint256 nextClaimTime = lastClaim + distributor.COOLDOWN();
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenDistributorForStakers.CooldownClaimNotReached.selector, nextClaimTime, lastClaim
            )
        );
        distributor.getTokens();
    }

    function testGetTokensRevertsWithNothingToClaim() public {
        vm.prank(staker);
        distributor.stake{value: 1}();

        vm.prank(staker);
        vm.expectRevert(TokenDistributorForStakers.NothingToClaim.selector);
        distributor.getTokens();
    }

    function testGetTokensSuccess() public {
        // 1 ETH в wei
        uint256 stakeAmount = 1 ether;

        // Считаем сколько токенов надо заминтить контракту
        uint256 expectedTokens = stakeAmount / distributor.MONEY_COFFICIENT(); // 2000

        // Учитываем decimals токена (обычно 18)

        // Минтим токены контракту
        token.mint(address(distributor), expectedTokens);

        // Стейкаем 1 ETH
        vm.prank(staker);
        distributor.stake{value: stakeAmount}();

        // Прокручиваем время, чтобы прошло cooldown
        vm.warp(block.timestamp + 8 days);

        // Баланс токенов стейкера до получения
        uint256 balanceBefore = token.balanceOf(staker);

        vm.prank(staker);
        bool success = distributor.getTokens();
        assertTrue(success);

        // Баланс токенов стейкера после получения
        uint256 balanceAfter = token.balanceOf(staker);

        // Проверяем, что получил ровно expectedTokens с учетом decimals
        assertEq(balanceAfter, balanceBefore + expectedTokens);
    }

    function testWithdrawOnlyOwnerReverts() public {
        vm.prank(staker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, staker));
        distributor.withdraw(1 ether);
    }

    function testWithdrawZeroReverts() public {
        vm.prank(owner);
        vm.expectRevert(TokenDistributorForStakers.AmountCantBeZero.selector);
        distributor.withdraw(0);
    }

    function testWithdrawInsufficientBalanceReverts() public {
        uint256 contractBalance = address(distributor).balance;
        uint256 withdrawAmount = 10 ether;

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenDistributorForStakers.InsufficientBalance.selector, contractBalance, withdrawAmount
            )
        );
        distributor.withdraw(withdrawAmount);
    }

    function testWithdrawSuccess() public {
        uint256 pre = address(owner).balance;
        vm.prank(owner);
        distributor.withdraw(1 ether);
        assertEq(address(owner).balance, pre + 1 ether);
    }
}
