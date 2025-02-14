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
    }

    // Events for EVM logging.
    event HiddenVote(address _player, bytes32 _hashedVote);

    // Links each player to an address to ensure single entry.
    mapping(address => Player) public players;

    address[] public playerQueue;  // Queue of players waiting for an opponent.
    uint public stake = 1 ether;   // Stake per player.


}
