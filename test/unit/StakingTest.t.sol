// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
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
    uint256 public constant STAKE_DURATION = 4 weeks;

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
        uint256 amountStaked = staking.getStakedBalance(HYBRID, 0);
        uint256 stakeDuration = staking.getStakeDuration(HYBRID, 0);
        uint256 stakeStartTime = staking.getStakeStartTime(HYBRID, 0);
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
        uint256 amountStaked = staking.getStakedBalance(HYBRID, 1);
        uint256 stakeDuration = staking.getStakeDuration(HYBRID, 1);
        uint256 stakeStartTime = staking.getStakeStartTime(HYBRID, 1);
        assertEq(amountStaked, USER_STAKE);
        assertEq(stakeDuration, STAKE_DURATION);
        assertEq(stakeStartTime, block.timestamp);
    }

    function testCannotClaimRewardsUntilDurationOver() public stake {
        vm.startPrank(HYBRID);
        vm.expectRevert(Staking.Staking__TokensLocked.selector);
        staking.claimReward(0);
        vm.stopPrank();
    }

    function testUserCannotClaimRewardIfNoStakedTokens() public stake {
        vm.startPrank(HYBRID);
        vm.warp(block.timestamp + 4 weeks);
        vm.roll(block.number + 10);
        staking.claimReward(0);
        vm.expectRevert(Staking.Staking__NotEnoughAmountStaked.selector);
        staking.claimReward(0);
        vm.stopPrank();
    }

    function testCannotClaimRewardsIfStakeDoesntExist() public stake {
        vm.startPrank(HYBRID);
        vm.expectRevert(Staking.Staking__StakeIndexInvalid.selector);
        staking.claimReward(5);
        vm.stopPrank();
    }

    function testUserCanClaimRewards() public stake {
        uint256 startingContractBalance = IERC20(ct).balanceOf(
            address(staking)
        );
        uint256 startingUserBalance = IERC20(ct).balanceOf(HYBRID);
        uint256 expectedReward = staking.getRewardBalance(HYBRID, 0);
        uint256 actualReward = staking.calculateReward(
            staking.getStakedBalance(HYBRID, 0),
            staking.getStakeDuration(HYBRID, 0)
        );
        vm.startPrank(HYBRID);
        vm.warp(block.timestamp + STAKE_DURATION);
        vm.roll(block.number + 10);
        staking.claimReward(0);
        vm.stopPrank();
        uint256 amountStaked = staking.getStakedBalance(HYBRID, 0);
        uint256 endContractBalance = IERC20(ct).balanceOf(address(staking));
        uint256 endUserBalance = IERC20(ct).balanceOf(HYBRID);
        uint256 rewardAfterClaiming = staking.getRewardBalance(HYBRID, 0);
        assertEq(expectedReward, actualReward);
        assertEq(amountStaked, 0);
        assertEq(rewardAfterClaiming, 0);
        assertEq(
            startingContractBalance,
            endContractBalance + USER_STAKE + expectedReward
        );
        assertEq(
            startingUserBalance + USER_STAKE + expectedReward,
            endUserBalance
        );
    }

    function testUserCanStakeAfterClaimingRewards() public stake {
        vm.startPrank(HYBRID);
        vm.warp(block.timestamp + STAKE_DURATION);
        vm.roll(block.number + 10);
        staking.claimReward(0);
        IERC20(ct).approve(address(staking), USER_STAKE);
        staking.stake(USER_STAKE, STAKE_DURATION);
        vm.stopPrank();
        uint256 amountStaked = staking.getStakedBalance(HYBRID, 1);
        uint256 stakeDuration = staking.getStakeDuration(HYBRID, 1);
        uint256 stakeStartTime = staking.getStakeStartTime(HYBRID, 1);
        assertEq(amountStaked, USER_STAKE);
        assertEq(stakeDuration, STAKE_DURATION);
        assertEq(stakeStartTime, block.timestamp);
    }

    function testCanCalculateReward() public stake {
        uint256 actualReward = staking.calculateReward(
            staking.getStakedBalance(HYBRID, 0),
            staking.getStakeDuration(HYBRID, 0)
        );
        uint256 amountStaked = staking.getStakedBalance(HYBRID, 0);
        uint256 weeklyRate = (staking.getUserStakeAprPercentage(HYBRID, 0) *
            amountStaked) / 100; //% of total amount staked
        uint256 expectedReward = (weeklyRate *
            staking.getStakeDuration(HYBRID, 0)) / 1 weeks;
        assertEq(actualReward, expectedReward);
    }

    function testCannotCheckTimeLeftIfInvalidStakeIndex() public {
        vm.startPrank(HYBRID);
        vm.expectRevert(Staking.Staking__StakeIndexInvalid.selector);
        staking.checkTimeLeftToUnlock(HYBRID, 4);
        vm.stopPrank();
    }

    function testCanCheckTimeLeft() public stake {
        uint256 expectedTimeLeft = STAKE_DURATION;
        uint256 actualTimeLeft = staking.checkTimeLeftToUnlock(HYBRID, 0);
        assertEq(actualTimeLeft, expectedTimeLeft);
        vm.warp(block.timestamp + 7 weeks);
        vm.roll(block.number + 30);
        uint256 timeLeft = staking.checkTimeLeftToUnlock(HYBRID, 0);
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

    function testOnlyAdminCanResumeStaking() public {
        vm.startPrank(admin);
        staking.pauseStaking();
        staking.resumeStaking();
        vm.stopPrank();
        assertEq(staking.isStakingPaused(), false);

        vm.startPrank(HYBRID);
        vm.expectRevert(Staking.Staking__NotAdmin.selector);
        staking.pauseStaking();
        vm.stopPrank();
    }

    function testOnlyAdminCanUpdateApr() public {
        vm.startPrank(HYBRID);
        uint256 duration = 1 weeks;
        uint256 newApr = 4;
        vm.expectRevert(Staking.Staking__NotAdmin.selector);
        staking.updateAPR(duration, newApr);
        vm.stopPrank();
    }

    function testAdminCanUpdateApr() public {
        vm.startPrank(admin);
        uint256 duration = 1 weeks;
        uint256 newApr = 4;
        staking.updateAPR(duration, newApr);
        vm.stopPrank();
        assertEq(staking.getAprPercentage(duration), newApr);
    }

    function testCanGetTotalTokensStaked() public stake {
        assertEq(staking.getTotalTokensStaked(), USER_STAKE);
        vm.startPrank(HYBRID);
        vm.warp(block.timestamp + STAKE_DURATION);
        vm.roll(block.number + 10);
        staking.claimReward(0);
        vm.stopPrank();
        assertEq(staking.getTotalTokensStaked(), 0);
    }

    function testConstructorSetsValues() public view {
        assertEq(address(staking.getCtToken()), address(ct));
        assertEq(staking.getAdmin(), admin);
        assertEq(staking.getAprPercentage(STAKE_DURATION), 12);
        assertEq(staking.getAprPercentage(1 weeks), 3);
    }
}
