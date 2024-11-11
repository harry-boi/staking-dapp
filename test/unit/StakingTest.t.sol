// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {Staking} from "../../src/Staking.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CodeToken} from "../../src/CodeToken.sol";
import {DeployStaking} from "../../script/DeployStaking.s.sol";

contract StakingTest is Test {
    DeployStaking deployer;
    Staking staking;
    CodeToken ct;
    address admin;
    address HYBRID = makeAddr("hybrid");
    uint256 public constant STAKING_SUPPLY = 1_000_000 * 10 ** 18;
    uint256 public constant USER_ALLOCATION = 10000e18;
    uint256 public constant USER_STAKE = 1000e18;
    uint256 public constant STAKE_DURATION = 3 weeks;

    function setUp() public {
        deployer = new DeployStaking();
        (staking, ct, admin) = deployer.run();
        vm.startPrank(admin);
        ct.transfer(address(staking), STAKING_SUPPLY);
        ct.transfer(HYBRID, USER_ALLOCATION);
        vm.stopPrank();
    }

    function testCanUseTokens() public {
        assertEq(IERC20(ct).balanceOf(address(staking)), STAKING_SUPPLY);
        assertEq(IERC20(ct).balanceOf(HYBRID), USER_ALLOCATION);
    }

    function testCannotStakeIfPaused() public {
        vm.startPrank(admin);
        staking.pauseStaking();
        vm.stopPrank();
        vm.startPrank(HYBRID);
        IERC20(ct).approve(address(staking), USER_STAKE);
        vm.expectRevert();
        staking.stake(USER_STAKE, STAKE_DURATION);
        vm.stopPrank();
    }

    function testCannotStakeIfAmountToStakeMoreThanUserBalance() public {
        vm.startPrank(HYBRID);
        IERC20(ct).approve(address(staking), USER_STAKE);
        vm.expectRevert(Staking.Staking__InsufficientBalanceToStake.selector);
        staking.stake(STAKING_SUPPLY, STAKE_DURATION);
        vm.stopPrank();
    }

    function testCannotStakeZeroTokens() public {
        vm.startPrank(HYBRID);
        IERC20(ct).approve(address(staking), USER_STAKE);
        vm.expectRevert(Staking.Staking__NotEnoughStakingAmount.selector);
        staking.stake(0, STAKE_DURATION);
        vm.stopPrank();
    }

    function testCannotStakeForLessThanAWeek() public {
        vm.startPrank(HYBRID);
        IERC20(ct).approve(address(staking), USER_STAKE);
        vm.expectRevert(Staking.Staking__NotEnoughStakingPeriod.selector);
        staking.stake(USER_STAKE, 6 days);
        vm.stopPrank();
    }

    modifier stake() {
        vm.startPrank(HYBRID);
        IERC20(ct).approve(address(staking), USER_STAKE);
        staking.stake(USER_STAKE, STAKE_DURATION);
        vm.stopPrank();
        _;
    }

    function testUserCanStake() public stake {
        assertEq(
            IERC20(ct).balanceOf(address(staking)),
            STAKING_SUPPLY + USER_STAKE
        );
        uint256 amountStaked = staking.getStakedBalance(HYBRID);
        uint256 stakeDuration = staking.getStakeDuration(HYBRID);
        uint256 stakeStartTime = staking.getStakeStartTime(HYBRID);
        assertEq(amountStaked, USER_STAKE);
        assertEq(stakeDuration, STAKE_DURATION);
        assertEq(stakeStartTime, block.timestamp);
    }

    function testUserCanStakeAfterStaking() public stake {
        vm.startPrank(HYBRID);
        IERC20(ct).approve(address(staking), USER_STAKE);
        staking.stake(USER_STAKE, STAKE_DURATION);
        vm.stopPrank();
        assertEq(
            IERC20(ct).balanceOf(address(staking)),
            STAKING_SUPPLY + USER_STAKE + USER_STAKE
        );
        uint256 amountStaked = staking.getStakedBalance(HYBRID);
        uint256 stakeDuration = staking.getStakeDuration(HYBRID);
        uint256 stakeStartTime = staking.getStakeStartTime(HYBRID);
        assertEq(amountStaked, USER_STAKE + USER_STAKE);
        assertEq(stakeDuration, STAKE_DURATION + STAKE_DURATION);
        assertEq(stakeStartTime, block.timestamp);
    }

    function testCannotUnstakeMoreThanStakedTokens() public stake {
        vm.startPrank(HYBRID);
        vm.expectRevert(Staking.Staking__InsufficientBalance.selector);
        staking.unstake(STAKING_SUPPLY);
        vm.stopPrank();
    }

    function testCannotUnstakeUntilAWeekAfter() public stake {
        vm.startPrank(HYBRID);
        vm.expectRevert(Staking.Staking__TokensLocked.selector);
        staking.unstake(USER_STAKE);
        vm.stopPrank();
    }

    function testUserCanUnstake() public stake {
        uint256 startingContractBalance = IERC20(ct).balanceOf(
            address(staking)
        );
        uint256 startingUserBalance = IERC20(ct).balanceOf(HYBRID);
        vm.startPrank(HYBRID);
        vm.warp(block.timestamp + 1 weeks);
        vm.roll(block.number + 10);
        staking.unstake(USER_STAKE);
        vm.stopPrank();
        uint256 amountStaked = staking.getStakedBalance(HYBRID);
        uint256 endContractBalance = IERC20(ct).balanceOf(address(staking));
        uint256 endUserBalance = IERC20(ct).balanceOf(HYBRID);
        assertEq(amountStaked, 0);
        assertEq(startingContractBalance, endContractBalance + USER_STAKE);
        assertEq(startingUserBalance + USER_STAKE, endUserBalance);
    }

    function testCanCalculateReward() public stake {
        uint256 stakedDuration = 1 weeks;
        uint256 expectedReward = staking.calculateReward(HYBRID);
        uint256 amountStaked = staking.getStakedBalance(HYBRID);
        uint256 weeklyRate = (staking.getAprPercentage(stakedDuration) * amountStaked) /
            100; //% of total amount staked
        uint256 weeksSinceStaked = (block.timestamp -
            staking.getStakeStartTime(HYBRID)) / 1 weeks;
        uint256 actualReward = weeklyRate * weeksSinceStaked;
        assertEq(actualReward, expectedReward);
    }

    function testUserCannotClaimRewardIfNoStakedTokens() public {
        vm.startPrank(HYBRID);
        vm.warp(block.timestamp + 1 weeks);
        vm.roll(block.number + 10);
        vm.expectRevert(Staking.Staking__NotEnoughAmountStaked.selector);
        staking.claimReward();
        vm.stopPrank();
    }

    function testCannotClaimIfStakeDurationIsNotOver() public stake {
        vm.startPrank(HYBRID);
        vm.expectRevert(Staking.Staking__StakeDurationNotComplete.selector);
        staking.claimReward();
        vm.stopPrank();
    }

    function testUserCanClaimReward() public stake {
        uint256 startingContractBalance = IERC20(ct).balanceOf(
            address(staking)
        );
        uint256 startingUserBalance = IERC20(ct).balanceOf(HYBRID);
        vm.startPrank(HYBRID);
        vm.warp(block.timestamp + 4 weeks);
        vm.roll(block.number + 30);
        staking.claimReward();
        vm.stopPrank();
        uint256 actualReward = staking.getRewardBalance(HYBRID);
        uint256 endContractBalance = IERC20(ct).balanceOf(address(staking));
        uint256 endUserBalance = IERC20(ct).balanceOf(HYBRID);
        uint256 expectedReward = endUserBalance - startingUserBalance;
        assertEq(actualReward, expectedReward);
        assertEq(startingContractBalance, endContractBalance + actualReward);
    }

    function testCanCheckTimeLeft() public stake {
        uint256 actualTimeLeft = STAKE_DURATION;
        uint256 expectedTimeLeft = staking.checkTimeLeftToUnlock(HYBRID);
        assertEq(actualTimeLeft, expectedTimeLeft);
        vm.warp(block.timestamp + 3 weeks);
        vm.roll(block.number + 30);
        uint256 timeLeft = staking.checkTimeLeftToUnlock(HYBRID);
        assertEq(timeLeft, 0);
    }

    function testOnlyAdminCanPauseStaking() public {
        vm.startPrank(admin);
        staking.pauseStaking();
        vm.stopPrank();

        assertEq(staking.isStakingPaused(), true);

        vm.startPrank(HYBRID);
        vm.expectRevert(Staking.Staking__NotAdmin.selector);
        staking.pauseStaking();
        vm.stopPrank();

    }

    function onlyAdminCanResumeStaking() public {
        vm.startPrank(admin);
        staking.resumeStaking();
        vm.stopPrank();
        assertEq(staking.isStakingPaused(), false);

        vm.startPrank(HYBRID);
        vm.expectRevert(Staking.Staking__NotAdmin.selector);
        staking.pauseStaking();
        vm.stopPrank();
    }

    function AdminCanUpdateApr() public {
        vm.startPrank(admin);
        uint256 duration = 1 weeks;
        uint256 newApr = 3;
        staking.updateAPR(duration, newApr);
        vm.stopPrank();
        assertEq(staking.getAprPercentage(duration), newApr);
    }



}
