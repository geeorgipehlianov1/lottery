// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

error Raffle__NotEnoughETHSend();
error Raffle__TransaferFailed();
error Raffle__NotOpen();
error Raffle__UpkeedNotNeeded(uint256 currentBalance, uint256 numberOfPlayers, uint256 raffleState);

/**@title A sample Raffle Contract
 * @author Georgi Pehlivanov
 * @notice This contract is for creating a sample raffle contract
 * @dev This implements the Chainlink VRF Version 2
 */
contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    // Type declaration
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    // State variables
    uint256 private immutable i_enranceFee;
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscripitionId;
    uint16 private constant REQUST_CONFERMATION = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    bool private s_open = true;
    RaffleState private s_raffleState;
    uint256 private s_lastTimestamp;

    // Lottery Variables
    address private s_recentWinner;
    uint256 private immutable i_interval;

    // events
    event RaffleEnter(address indexed player);
    event RequestetRaffleWinner(uint256 indexed requsetId);
    event WinnerPicker(address indexed winner);


    /* Functions */
    constructor(
        address vrfCordinatorV2,
        uint256 entranceFee,
        bytes32 gasLane,
        uint64 subscripitionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCordinatorV2) {
        i_enranceFee = entranceFee;
        i_vrfCordinator = VRFCoordinatorV2Interface(vrfCordinatorV2);
        i_gasLane = gasLane;
        i_subscripitionId = subscripitionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimestamp = block.timestamp;
        i_interval = interval;
    }

    function enterRaffle() public payable {
        // require(msg.value < i_enranceFee, "Not enough ETH send!") -> Less gas efficient;
        if (msg.value < i_enranceFee) {
            revert Raffle__NotEnoughETHSend();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    function performUpkeep(bytes calldata /* performData */) external override {

        (bool upkeepNeeded, ) = checkUpkeep("");

        if(!upkeepNeeded) {
            revert Raffle__UpkeedNotNeeded(
            address(this).balance,
            s_players.length,
            uint256(s_raffleState)
        );
        }

        s_raffleState = RaffleState.CALCULATING;

        uint256 requestId = i_vrfCordinator.requestRandomWords(
            i_gasLane,
            i_subscripitionId,
            REQUST_CONFERMATION,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit RequestetRaffleWinner(requestId);
    }

    function fulfillRandomWords(uint256 /* requsetId */, uint256[] memory randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;
        (bool success, ) = recentWinner.call{ value: address(this).balance }("");
        if (!success) {
            revert Raffle__TransaferFailed();
        }
        emit WinnerPicker(recentWinner);
    }

    /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for `upkeepNeeded` to return True.
     * the following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH.
     * 4. Implicity, your subscription is funded with LINK.
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public override returns(bool upkeepNeeded, bytes memory /* performData */) {
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool timePassed = ((block.timestamp - s_lastTimestamp) > i_interval);
        bool hasPlayers = s_players.length > 1;
        bool hasBalance = address(this).balance > 0;

        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);

    }

    function getEntranceFee() public view returns (uint256) {
        return i_enranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffeleSate() public view returns(RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns(uint256) {
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public view returns(uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() public view returns(uint256) {
        return s_lastTimestamp;
    } 

    function getRequsetConfirmations() public pure returns(uint256) {
        return REQUST_CONFERMATION;
    }
}
