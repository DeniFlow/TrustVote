// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

contract Voting {

    error NameVoteSessionCantBeEmpty();
    error StartTimeMoreOrEqualEndTime();
    error StartTimeLessTimestamp();
    error EndTimeLessTimestamp();
    error VoterAddressCantBeZero();
    error VoteSessionNotFound(uint256 idVoteSession, uint256 countVoteSessions);
    error CountChoosesCantBeZero();
    error CountChoosesMoreFour();
    error ChoiceLengthCantBeZero();
    error ChoiceNotFound(uint256 idVoteSession, uint256 countChoisesVoteSession, uint256 indChoice);
    error VoteSessionNotStarted(uint256 idVoteSession, uint256 startTime, uint256 timestamp);
    error VoteSessionEndTimeNotReached(uint256 idVoteSession, uint256 endTime, uint256 timestamp);
    error VoteSessionHasEnded(uint256 idVoteSession, uint256 startTime, uint256 timestamp);
    error VoterAlreadyVoted(uint256 idVoteSession);
    error UserNotVoterInThisVoteSession(uint256 idVoteSession);
    error VoteSessionAlreadyEnded();

    event VoteSessionCreated(uint256 voteSessionId, string name, uint256 startTime, uint256 endTime);
    event Voted(uint256 voteSessionId, address voter, string choice);
    event VoteSessionEnded(uint256 voteSessionId, uint256 countVoters, StatusVoteSession status, string[] winners);

    enum StatusVoteSession {
        Created,
        Active,
        Ended,
        Rejected
    }
    enum VoteAccess {
        Public,
        Yes,
        No
    }
    enum VoteChoice {
        Choice1,
        Choice2,
        Choice3,
        Choice4
    }

    struct Choice {
        string title;
        uint256 countVotes;
    }

    struct Voter {
        address addr;
        bool hasVoted;
        string choice;
        VoteAccess canVote;
    }

    struct VoteSession {
        uint256 id;
        address creatorAddr;
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 minNumberVotes;
        uint256 tempNumberVotes;
        bool isPrivate;
        mapping(address => Voter) voters;
        StatusVoteSession status;
        Choice[] choices;
        string[] winners;
    }

    uint256 public constant MAX_COUNT_CHOICES = 4;
    uint256 public countVoteSessions;
    mapping(uint256 => VoteSession) public voteSessions;
    mapping(address => uint256[]) public votingCreatedByAddress;
    mapping(address => uint256[]) public votingParticipatedByAddress;

    function addVoteSession(
        string calldata _title,
        string calldata _description,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _minNumberVotes,
        bool _isPrivate,
        Voter[] memory _voters,
        string[] calldata _choices
    ) external {
        if (bytes(_title).length == 0) revert NameVoteSessionCantBeEmpty();
        if (_startTime >= _endTime) revert StartTimeMoreOrEqualEndTime();
        if (_startTime < block.timestamp) revert StartTimeLessTimestamp();
        if (_endTime < block.timestamp) revert EndTimeLessTimestamp();
        if (_choices.length == 0) revert CountChoosesCantBeZero();
        if (_choices.length > MAX_COUNT_CHOICES) revert CountChoosesMoreFour();
        if (_isPrivate) {
            for (uint256 i = 0; i < _voters.length; i++) {
                if (_voters[i].addr == address(0)) {
                    revert VoterAddressCantBeZero();
                }
                _voters[i].canVote = VoteAccess.Yes;
            }
        }
        for (uint256 i = 0; i < _choices.length; i++) {
            if (bytes(_choices[i]).length == 0) revert ChoiceLengthCantBeZero();
        }
        countVoteSessions++;
        VoteSession storage voteSession = voteSessions[countVoteSessions];
        voteSession.id = countVoteSessions;
        voteSession.creatorAddr = msg.sender;
        voteSession.title = _title;
        voteSession.description = _description;
        voteSession.startTime = _startTime;
        voteSession.endTime = _endTime;
        voteSession.minNumberVotes = _minNumberVotes;
        voteSession.tempNumberVotes = 0;
        voteSession.isPrivate = _isPrivate;
        for (uint256 i = 0; i < _voters.length; i++) {
            voteSession.voters[_voters[i].addr] = _voters[i];
        }
        for (uint256 i = 0; i < _choices.length; i++) {
            voteSession.choices.push(Choice(_choices[i], 0));
        }
        voteSession.status = StatusVoteSession.Created;

        votingCreatedByAddress[msg.sender].push(voteSession.id);
        emit VoteSessionCreated(voteSession.id, voteSession.title, voteSession.startTime, voteSession.endTime);
    }

    function vote(uint256 _voteSessionId, uint256 _indChoice) external {
        if (_voteSessionId > countVoteSessions || _voteSessionId == 0) {
            revert VoteSessionNotFound(_voteSessionId, countVoteSessions);
        }
        VoteSession storage voteSession = voteSessions[_voteSessionId];
        uint256 countChoices = voteSession.choices.length;
        if (_indChoice > countChoices) {
            revert ChoiceNotFound(_voteSessionId, countChoices, _indChoice);
        }
        if (block.timestamp < voteSession.startTime) {
            revert VoteSessionNotStarted(_voteSessionId, voteSession.startTime, block.timestamp);
        }
        if (
            block.timestamp > voteSession.endTime || voteSession.status == StatusVoteSession.Ended
                || voteSession.status == StatusVoteSession.Rejected
        ) {
            revert VoteSessionHasEnded(_voteSessionId, voteSession.endTime, block.timestamp);
        }
        if (voteSession.voters[msg.sender].hasVoted) {
            revert VoterAlreadyVoted(_voteSessionId);
        }
        if (voteSession.isPrivate) {
            if (
                voteSession.voters[msg.sender].canVote == VoteAccess.Public
                    || voteSession.voters[msg.sender].canVote == VoteAccess.No
            ) {
                revert UserNotVoterInThisVoteSession(_voteSessionId);
            }
        }
        if (block.timestamp >= voteSession.startTime && voteSession.status == StatusVoteSession.Created) {
            voteSession.status = StatusVoteSession.Active;
        }
        voteSession.voters[msg.sender].hasVoted = true;
        voteSession.choices[_indChoice].countVotes++;
        voteSession.tempNumberVotes++;
        voteSession.voters[msg.sender].choice = voteSession.choices[_indChoice].title;

        votingParticipatedByAddress[msg.sender].push(voteSession.id);

        emit Voted(_voteSessionId, msg.sender, voteSession.voters[msg.sender].choice);
    }

    function endVoteSession(uint256 _voteSessionId) public {
        if (_voteSessionId > countVoteSessions || _voteSessionId == 0) {
            revert VoteSessionNotFound(_voteSessionId, countVoteSessions);
        }
        VoteSession storage voteSession = voteSessions[_voteSessionId];
        uint256 countChoices = voteSession.choices.length;
        if (block.timestamp < voteSession.endTime) {
            revert VoteSessionEndTimeNotReached(_voteSessionId, voteSession.endTime, block.timestamp);
        }
        if (voteSession.status == StatusVoteSession.Ended || voteSession.status == StatusVoteSession.Rejected) {
            revert VoteSessionAlreadyEnded();
        }
        if (voteSession.tempNumberVotes < voteSession.minNumberVotes) {
            voteSession.status = StatusVoteSession.Rejected;
        } else {
            voteSession.status = StatusVoteSession.Ended;
            uint256 maxCountVotes;
            for (uint256 i = 0; i < countChoices; i++) {
                if (voteSession.choices[i].countVotes >= maxCountVotes) {
                    maxCountVotes = voteSession.choices[i].countVotes;
                }
            }
            for (uint256 i = 0; i < countChoices; i++) {
                if (voteSession.choices[i].countVotes == maxCountVotes) {
                    voteSession.winners.push(voteSession.choices[i].title);
                }
            }
        }

        emit VoteSessionEnded(_voteSessionId, voteSession.tempNumberVotes, voteSession.status, voteSession.winners);
    }

    function getVotingCreatedByAddress(address _voter) public view returns (uint256[] memory) {
        if (_voter == address(0)) revert VoterAddressCantBeZero();
        return votingCreatedByAddress[_voter];
    }

    function getVotingParticipatedByAddress(address _voter) public view returns (uint256[] memory) {
        if (_voter == address(0)) revert VoterAddressCantBeZero();
        return votingParticipatedByAddress[_voter];
    }
}
