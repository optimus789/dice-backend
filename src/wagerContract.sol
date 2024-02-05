// SPDX-License-Identifier: MIT
pragma solidity ^ 0.8.7;

interface IDiceToken {
    function transferFrom(address recipient, address to, uint amount) external returns(bool);
    function transfer(address to, uint amount) external returns(bool);
    function balanceOf(address account) external view returns(uint);
}

contract Wager {
    // Game Variables
    string public gameState = "WAIT";
    uint256 public roundId = 0;
    address public managerAddress;
    IDiceToken public DICE;

    // Bets and Winners
    struct Bet {
        uint256 side;
        uint256 amount;
    }
    mapping(address => Bet) public bets;
    mapping(uint256 => address[]) sideBets;

    event BetPlaced(address indexed player, uint256 side, uint256 amount);
    event RoundFinished(uint256 indexed roundId, uint256 winningSide, address[] winners);

    // Constructor
    constructor(address _DICEAddress)
    {
        DICE = IDiceToken(_DICEAddress);
    }

    modifier onlyManager() {
        require(msg.sender == managerAddress, "Only manager can call this");
        _;
    }

    function startWait() public onlyManager {
        require(keccak256(abi.encodePacked(gameState)) != keccak256(abi.encodePacked("WAIT")), "Game already in WAIT state");
        gameState = "WAIT";
        roundId++;
    }

    function placeBet(uint256 _side, uint256 _amount) public {
        require(keccak256(abi.encodePacked(gameState)) == keccak256(abi.encodePacked("WAIT")), "Not accepting bets now");
        require(_side >= 1 && _side <= 6, "Invalid side");
        require(DICE.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        bets[msg.sender] = Bet({ side: _side, amount: _amount });
        sideBets[_side].push(msg.sender);

        emit BetPlaced(msg.sender, _side, _amount);
    }

    // function requestRandomWords()
    // external
    // onlyManager
    // returns(uint256 requestId)
    // {
    //     require(keccak256(abi.encodePacked(gameState)) == keccak256(abi.encodePacked("WAIT")), "Game not in correct state to finish");
    //     gameState = "FINISH";
    //     // Will revert if subscription is not set and funded.
    //     return requestId;
    // }

    // function fulfillRandomWords(
    //     uint256[] memory _randomWords
    // ) internal {
    //     uint256 winningSide = (_randomWords[0] % 6) + 1;
    //     distributeRewards(winningSide);
    // }

    function manualGameEnd(uint256 numberSide) public onlyManager {
        uint256 winningSide = numberSide;
        gameState = "FINISH";
        distributeRewards(winningSide);
    }

    function distributeRewards(uint256 winningSide) internal {
        address[] memory winners = sideBets[winningSide];
        uint256 pool = DICE.balanceOf(address(this));
        uint256 totalRewardAmount = 0;

        for (uint256 i = 0; i < winners.length; i++) {
            totalRewardAmount += bets[winners[i]].amount;
        }

        require(pool >= totalRewardAmount, "Contract does not have enough tokens to distribute");

        if (winners.length > 0) {
            uint256 rewardPerWinner = pool / winners.length;
            for (uint256 i = 0; i < winners.length; i++) {
                require(DICE.transfer(winners[i], rewardPerWinner), "Transfer failed");
            }
        }

        emit RoundFinished(roundId, winningSide, winners);

        // Reset for next round
        gameState = "WAIT";
        for (uint i = 1; i <= 6; i++) {
            delete sideBets[i];
        }
        roundId++;
    }

}