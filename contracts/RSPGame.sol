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
    event GameStart(address _player1, address _player2, uint _deadline);

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
    function play(bytes32 _hashedVote) public payable  {

        // Checks if the player already is in a game.
        require(players[msg.sender].hashedVote == 0, "You are already playing");

         // Checks if the player has paid the stake requirement.
        require(msg.value >= stake, "The stake must be 1 Ether");

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
}
