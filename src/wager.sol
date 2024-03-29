// SPDX-License-Identifier: MIT
pragma solidity ^ 0.8.7;
import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";
import "@openzeppelin/contracts@4.9.5/access/Ownable.sol";
interface IDiceToken {
    function transferFrom(address recipient, address to, uint amount) external returns(bool);
    function transfer(address to, uint amount) external returns(bool);
    function balanceOf(address account) external view returns(uint);
}

contract Wager is RrpRequesterV0, Ownable {
    // Game Variables
    event RequestedUint256(bytes32 indexed requestId);
    event ReceivedUint256(bytes32 indexed requestId, uint256 response);
    event RequestedUint256Array(bytes32 indexed requestId, uint256 size);
    event ReceivedUint256Array(bytes32 indexed requestId, uint256[] response);
    event WithdrawalRequested(address indexed airnode, address indexed sponsorWallet);

    address public airnode;                 // The address of the QRNG Airnode
    bytes32 public endpointIdUint256;       // The endpoint ID for requesting a single random number
    bytes32 public endpointIdUint256Array;  // The endpoint ID for requesting an array of random numbers
    address public sponsorWallet;           // The wallet that will cover the gas costs of the request
    uint256 public _qrngUint256;            // The random number returned by the QRNG Airnode
    uint256[] public _qrngUint256Array;     // The array of random numbers returned by the QRNG Airnode
    mapping(bytes32 => bool) public expectingRequestWithIdToBeFulfilled;

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
    constructor(address _DICEAddress, address _airnodeRrp)  RrpRequesterV0(_airnodeRrp)
    {
        DICE = IDiceToken(_DICEAddress);
    }

    /// @notice Sets the parameters for making requests
    function setRequestParameters(
        address _airnode,
        bytes32 _endpointIdUint256,
        bytes32 _endpointIdUint256Array,
        address _sponsorWallet
    ) external {
        airnode = _airnode;
        endpointIdUint256 = _endpointIdUint256;
        endpointIdUint256Array = _endpointIdUint256Array;
        sponsorWallet = _sponsorWallet;
    }

    /// @notice To receive funds from the sponsor wallet and send them to the owner.
    receive() external payable {
        payable(owner()).transfer(msg.value);
        emit WithdrawalRequested(airnode, sponsorWallet);
    }

    /// @notice Requests a `uint256`
    /// @dev This request will be fulfilled by the contract's sponsor wallet,
    /// which means spamming it may drain the sponsor wallet.
    function makeRequestUint256() external {
        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256,
            address(this),
            sponsorWallet,
            address(this),
            this.fulfillUint256.selector,
            ""
        );
        expectingRequestWithIdToBeFulfilled[requestId] = true;
        emit RequestedUint256(requestId);
    }

    /// fulfill the request
    function fulfillUint256(bytes32 requestId, bytes calldata data)
        external
        onlyAirnodeRrp
    {
        require(
            expectingRequestWithIdToBeFulfilled[requestId],
            "Request ID not known"
        );
        expectingRequestWithIdToBeFulfilled[requestId] = false;
        uint256 qrngUint256 = abi.decode(data, (uint256));
        _qrngUint256 = qrngUint256;
        // Do what you want with `qrngUint256` here...
        uint256 winningSide = _qrngUint256 % 6 + 1;
        emit ReceivedUint256(requestId, qrngUint256);
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

    function manualGameEnd() public onlyManager {
        uint256 winningSide = _qrngUint256 % 6 + 1;
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