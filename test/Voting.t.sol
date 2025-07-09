// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Voting} from "../src/Voting.sol";

contract VotingTest is Test {
    Voting public voting;
    address public creator = address(1);
    address public voter1 = address(2);
    address public voter2 = address(3);

    function setUp() public {
        voting = new Voting();
        vm.deal(creator, 1 ether);
        vm.deal(voter1, 1 ether);
        vm.deal(voter2, 1 ether);
    }

    // Тест успешного создания голосования
    function test_addVoteSession_Success() public {
        vm.startPrank(creator);
        uint256 startTime = block.timestamp + 1 hours;
        uint256 endTime = startTime + 1 days;

        Voting.Voter[] memory voters = new Voting.Voter[](2);
        voters[0] = Voting.Voter(voter1, false, "", Voting.VoteAccess.Yes);
        voters[1] = Voting.Voter(voter2, false, "", Voting.VoteAccess.Yes);

        string[] memory choices = new string[](2);
        choices[0] = "Choice 1";
        choices[1] = "Choice 2";

        uint256 sessionId = voting.countVoteSessions() + 1;

        vm.expectEmit(true, true, true, true);
        emit Voting.VoteSessionCreated(sessionId, "Test Vote", startTime, endTime);

        voting.addVoteSession("Test Vote", "Description", startTime, endTime, 10, true, voters, choices);

        // Проверка, что голосование создано
        assertEq(voting.countVoteSessions(), 1);
        (uint256 id, address creatorAddr, string memory title,, uint256 _startTime, uint256 _endTime,,, bool isPrivate,)
        = voting.voteSessions(1);

        assertEq(id, 1);
        assertEq(creatorAddr, creator);
        assertEq(title, "Test Vote");
        assertEq(_startTime, startTime);
        assertEq(_endTime, endTime);
        assertEq(isPrivate, true);

        // Проверка, что голосование добавлено в `votingCreatedByAddress`
        uint256[] memory createdSessions = voting.getVotingCreatedByAddress(creator);
        assertEq(createdSessions.length, 1);
        assertEq(createdSessions[0], 1);
    }

    function test_addVoteSession_Revert_EmptyTitle() public {
        vm.startPrank(creator);
        uint256 startTime = block.timestamp + 1 hours;
        uint256 endTime = startTime + 1 days;

        Voting.Voter[] memory voters = new Voting.Voter[](2);
        voters[0] = Voting.Voter(voter1, false, "", Voting.VoteAccess.Yes);
        voters[1] = Voting.Voter(voter2, false, "", Voting.VoteAccess.Yes);

        string[] memory choices = new string[](2);
        choices[0] = "Choice 1";
        choices[1] = "Choice 2";

        vm.expectRevert(Voting.NameVoteSessionCantBeEmpty.selector);

        voting.addVoteSession("", "Description", startTime, endTime, 10, true, voters, choices);
    }

    function test_addVoteSession_Revert_InvalidTimes() public {
        vm.startPrank(creator);
        console.log("Timestamp:", block.timestamp);

        Voting.Voter[] memory voters = new Voting.Voter[](2);
        voters[0] = Voting.Voter(voter1, false, "", Voting.VoteAccess.Yes);
        voters[1] = Voting.Voter(voter2, false, "", Voting.VoteAccess.Yes);

        string[] memory choices = new string[](2);
        choices[0] = "Choice 1";
        choices[1] = "Choice 2";

        uint256 startTime = 0;
        uint256 endTime = block.timestamp + 1 days;

        vm.expectRevert(Voting.StartTimeLessTimestamp.selector);

        voting.addVoteSession("Test", "Description", startTime, endTime, 10, true, voters, choices);

        startTime = block.timestamp + 20;
        endTime = block.timestamp + 10;

        vm.expectRevert(Voting.StartTimeMoreOrEqualEndTime.selector);

        voting.addVoteSession("Test", "Description", startTime, endTime, 10, true, voters, choices);
    }
}
