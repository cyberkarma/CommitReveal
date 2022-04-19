// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Voting {
    uint public immutable votingDeadline;
    uint public immutable revealDeadline;
    uint public immutable candidateAdditionDeadline;

    uint public constant RATE = 10;

    struct Candidate {
        string statement;
        address account;
    }
    Candidate[] public candidates;
    mapping(address => bytes32) public commitments;
    mapping(address => uint) public votes;

    address winner;
    bool stopped;

    event CandidateAdded(address account, string statement);
    event VotesIncresed(address candidate, uint votes);
    event Winner(address winner);

    constructor(uint _candidateAdditionDuration, uint _votingDuration, uint _revealDuration) {
        candidateAdditionDeadline = block.timestamp + _candidateAdditionDuration;
        votingDeadline = candidateAdditionDeadline + _votingDuration;
        revealDeadline = votingDeadline + _revealDuration;
    }

    function becomeCandidate(string memory _statement) external payable {
        require(candidateAdditionDeadline >= block.timestamp, "too late!");
        require(msg.value == 1 ether, "incorrect payment!");
        require(!strEq(_statement, ""), "incorrect statement!");

        Candidate memory newCandidate = Candidate({
        statement: _statement,
        account: msg.sender
        });

        candidates.push(newCandidate);

        emit CandidateAdded(msg.sender, _statement);
    }

    // 0xe2d9ac6091aaf9ea14f68fe4f6ee7388d9f5c41574a0446250d45dba772c10d5
    function vote(bytes32 commitment) external {
        require(votingDeadline >= block.timestamp, "too late!");

        commitments[msg.sender] = commitment;
    }

    function reveal(address votedFor, string memory password) external {
        require(revealDeadline >= block.timestamp && block.timestamp > votingDeadline, "too late!");

        bytes32 hash = keccak256(abi.encodePacked(
                votedFor, msg.sender, password
            ));

        require(hash == commitments[msg.sender], "incorrect data!");
        require(candidatePresent(votedFor), "invalid candidate!");

        delete commitments[msg.sender];
        votes[votedFor]++;

        emit VotesIncresed(votedFor, votes[votedFor]);
    }

    function votingResults() external {
        require(!stopped, "stopped");
        require(block.timestamp > revealDeadline, "too early!");

        address currentWinner;
        uint currentWinnerVotes;

        for(uint i = 0; i < candidates.length; i++) {
            Candidate memory nextCandidate = candidates[i];

            if(votes[nextCandidate.account] >= currentWinnerVotes) {
                currentWinner = nextCandidate.account;
            }
        }

        winner = currentWinner;
        stopped = true;
        uint balance = address(this).balance;
        payable(winner).transfer(balance - ((balance * RATE) / 100));
        emit Winner(winner);
    }

    function candidatePresent(address candidate) private view returns(bool) {
        for(uint i = 0; i < candidates.length; i++) {
            Candidate memory nextCandidate = candidates[i];
            if (nextCandidate.account == candidate) {
                return true;
            }
        }

        return false;
    }

    function strEq(string memory str1, string memory str2) private pure returns(bool) {
        return keccak256(abi.encode(str1)) == keccak256(abi.encode(str2));
    }
}