// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;


/**
 * @title Rock-Paper-Scissors Game Contract
 * @author Johan F. Wilvang
 * @notice This contract allows players to participate in a Rock-Paper-Scissors game with a stake.
 *         Players submit their hashed votes and later reveal them to determine the winner.
 * @dev The contract handles player registration, vote submission, vote revealing, and stake withdrawal.
 */
contract RPSGame {

    // This declares a new complex type 'Player' which will
    // be used for variables later. It will represent a
    // single player.
    struct Player {
        string vote;         // The player's vote {'R', 'P', 'S'}.
        bytes32 hashedVote;  // The vote hashed with salt.
        bool revealed;       // If true, the player's vote is revealed.
        address opponent;    // The address of the opponent.
        uint deadline;       // The deadline to reveal the vote.
    }

    // Events for EVM logging.
    event HiddenVote(address _player, bytes32 _hashedVote);
    event RevealedVote(address _player, string _vote);
    event GameStart(address _player1, address _player2, uint _deadline);
    event Withdraw(address _winner, uint _amount);

    // Links each player to an address to ensure single entry.
    mapping(address => Player) public players;

    address[] public playerQueue;  // Queue of players waiting for an opponent.
    uint public stake = 1 ether;   // Stake per player.
    uint public revealTime = 480;  // 8 minutes in seconds.

    /**
     * @notice The vote must be a valid character ('R', 'P', 'S')
     *         and be concatenated with salt. The hashing
     *         algorithm to be used is keccak256.
     * @notice The player must deposit a stake of 1 Ether to join.
     * @dev Allows a player to join the game with a hashed vote.
     * @param _hashedVote The hashed vote of the player.
     */
    function play(bytes32 _hashedVote) public payable isNewPlayer costs(stake) {

        // Creates a new player.
        players[msg.sender] = Player({
            hashedVote: _hashedVote,
            vote: "",
            revealed: false,
            opponent: address(0),
            deadline: 0
        });

        uint queueLength = playerQueue.length; // Finds the length of the player queue.

        if (queueLength == 0) {
            // Adds the player to the waiting queue if empty.
            playerQueue.push(msg.sender);

        } else {
            // Selects the last player in the queue as the opponent
            // and vice versa.
            address opponent = playerQueue[queueLength - 1];
            players[msg.sender].opponent = opponent;
            players[opponent].opponent = msg.sender;

            // Starts the deadline for the revealing
            uint deadline = block.timestamp + revealTime;
            players[msg.sender].deadline = deadline;
            players[opponent].deadline = deadline;

            // Removes the opponent from the waiting queue and starts the game.
            playerQueue.pop();
            emit GameStart(opponent, msg.sender, deadline);
        }

        // Logs the hidden vote to the player.
        emit HiddenVote(msg.sender, _hashedVote);
    }

    /**
     * @notice To reveal the vote, the player must use
     *         the same vote and salt used to create the hash.
     * @dev Allows a player to reveal their vote.
     *      The vote will be converted to uppercase if
     *      it was originally in lowercase.
     * @param _vote The vote of the player.
     * @param _salt The salt used to hash the vote.
     */
    function reveal(string calldata _vote, string calldata _salt) public hasOpponent validVote(_vote, _salt) {

        bytes memory bStr = bytes(_vote); // Byte value of the character.

        // Checks if the vote is lowercase.
        if (bStr[0] >= 0x61 && bStr[0] <= 0x7A) {
            // Convert to uppercase by subtracting 32
            bStr[0] = bytes1(uint8(bStr[0]) - 32);
        }

        // Updates the player status.
        players[msg.sender].revealed = true;
        players[msg.sender].vote = string(bStr);

        // Logs the vote to the player in plain text.
        emit RevealedVote(msg.sender, string(bStr));
    }

    /**
     * @notice You can only withdraw on victory, tie, or timeout of the deadline.
     * @dev Allows a player to withdraw their stake if conditions are met.
     */
    function withdraw() public payable canWithdraw {

        address opponent = players[msg.sender].opponent; // The opponent's address.
        string memory vote1 = players[msg.sender].vote;  // The player's vote.
        string memory vote2 = players[opponent].vote;    // The opponent's vote.

        // Checks for either victory or timeout.
        if (isWinner(vote1, vote2) || (block.timestamp >=
        players[msg.sender].deadline && !players[opponent].revealed)) {
            // Transfers the stakes to the winner.
            payable(msg.sender).transfer(stake * 2);

            // Removes the players from the game.
            delete players[msg.sender];
            delete players[opponent];

            // Logs the withdrawal
            emit Withdraw(msg.sender, stake * 2);

        // Checks if there was a tie.
        } else if (compareStrings(vote1, vote2)) {
            // Transfers the stake back to each player.
            payable(msg.sender).transfer(stake);
            payable(opponent).transfer(stake);

            // Removes the players from the game.
            delete players[msg.sender];
            delete players[opponent];

            // Logs the withdrawals
            emit Withdraw(msg.sender, stake);
            emit Withdraw(opponent, stake);
        }
    }

    /**
     * @dev Compares two strings for equality.
     * @param a The first string.
     * @param b The second string.
     * @return True if the strings are equal, false otherwise.
     */
    function compareStrings(string memory a, string memory b) public pure returns (bool) {
        // Compares the hash values of two strings.
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    /**
     * @dev Modifier to check if the player is new.
     */
    modifier isNewPlayer() {
        // Checks if the player already is in a game.
        require(players[msg.sender].hashedVote == 0, "You are already playing");
        _;
    }

    /**
     * @dev Modifier to check if the player has paid the stake requirement.
     * @param _amount The required stake amount.
     */
    modifier costs(uint _amount) {
        // Checks if the player has paid the stake requirement.
        require(msg.value >= stake, "The stake must be 1 Ether");
        _;
    }

    /**
     * @dev Modifier to check if the player has an opponent.
     */
    modifier hasOpponent() {
        // Checks if the player has an opponent.
        require(players[msg.sender].opponent != address(0), "Waiting for an opponent");
        _;
    }

    /**
     * @dev Modifier to check if the player can withdraw.
     */
    modifier canWithdraw() {
        // Checks if the player has revealed their vote.
        require(players[msg.sender].revealed, "You must reveal your vote before withdrawal");

        // Checks if the deadline is reached or the
        // other player has revealed their vote.
        require(
            block.timestamp >= players[msg.sender].deadline ||
            players[players[msg.sender].opponent].revealed,
            "Waiting for opponent to reveal or deadline"
        );
        _;
    }

    /**
     * @dev Modifier to check the integrity of the revealed vote.
     * @param _vote The revealed vote.
     * @param _salt The salt used to hash the vote.
     */
    modifier validVote(string memory _vote, string memory _salt) {
        // Checks the integrity of the revealed vote.
        bytes32 hash = keccak256(abi.encodePacked(_vote, _salt));
        require(players[msg.sender].hashedVote == hash, "Not a valid vote");
        _;
    }

    /**
     * @dev Modifier to check if the vote is a valid choice.
     * @param _vote The vote to check.
     */
    modifier validChoice(string memory _vote) {
        // Checks if the vote is a valid choice.
        require(compareStrings(_vote, "R") || compareStrings(_vote, "P") || compareStrings(_vote, "S"),
        "You did not choose rock, paper or scissors");
        _;
    }

    /**
     * @dev Determines if the first vote is the winner.
     * @param _vote1 The first vote.
     * @param _vote2 The second vote.
     * @return True if the first vote is the winner, false otherwise.
     */
    function isWinner(string memory _vote1, string memory _vote2) public pure validChoice(_vote1) returns(bool) {
        // Both players chose the same option.
        if (compareStrings(_vote1, _vote2) || compareStrings(_vote2, "")) return false;
        // Paper beats rock
        else if (compareStrings(_vote1, "R") && compareStrings(_vote2, "P")) return false;
        // Scissor beats paper
        else if (compareStrings(_vote1, "P") && compareStrings(_vote2, "S")) return false;
        // Rock beats scissor
        else if (compareStrings(_vote1, "S") && compareStrings(_vote2, "R")) return false;
        // Victory to vote 1.
        else  return true;
    }
}