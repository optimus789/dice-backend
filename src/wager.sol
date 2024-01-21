// SPDX-License-Identifier: MIT
pragma solidity ^ 0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

interface IGhoToken {
    function transferFrom(address recipient, address to, uint amount) external returns(bool);
function transfer(address to, uint amount) external returns(bool);
function balanceOf(address account) external view returns(uint);
}

contract Wager is VRFConsumerBaseV2, ConfirmedOwner {
    //chainlink variables
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus)
        public s_requests; /* requestId --> requestStatus */
    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;
    uint256 public lastRequestIds;
    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    bytes32 keyHash =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 1000000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 2;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 2;
    // Game Variables
    string public gameState = "WAIT";
    uint256 public roundId = 0;
    address public managerAddress;
    IGhoToken public ghoToken;

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
    constructor(address _ghoTokenAddress, uint64 subscriptionId)
    VRFConsumerBaseV2(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625)
    ConfirmedOwner(msg.sender)
    {
        COORDINATOR = VRFCoordinatorV2Interface(
            0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
        );
        s_subscriptionId = subscriptionId;
        managerAddress = msg.sender;
        ghoToken = IGhoToken(_ghoTokenAddress);
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
        require(ghoToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        bets[msg.sender] = Bet({ side: _side, amount: _amount });
        sideBets[_side].push(msg.sender);

        emit BetPlaced(msg.sender, _side, _amount);
    }

    function requestRandomWords()
    external
    onlyOwner
    returns(uint256 requestId)
    {
        require(keccak256(abi.encodePacked(gameState)) == keccak256(abi.encodePacked("WAIT")), "Game not in correct state to finish");
        gameState = "FINISH";
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);
        uint256 winningSide = (_randomWords[0] % 6) + 1;
        distributeRewards(winningSide);
    }

    function manualfulfill(uint256 numberSide) public onlyManager {
        uint256 winningSide = numberSide;
        gameState = "FINISH";
        distributeRewards(winningSide);
    }

    //  function callFinish(uint256 numberSide) public onlyManager {
    //     uint256 winningSide = numberSide;
    //     gameState = "FINISH";
    //     requestRandomness(callbackGasLimit, requestConfirmations, numWords);
    //     distributeRewards(winningSide);
    // }

    function distributeRewards(uint256 winningSide) internal {
        address[] memory winners = sideBets[winningSide];
        uint256 pool = ghoToken.balanceOf(address(this));
        uint256 totalRewardAmount = 0;

        for (uint256 i = 0; i < winners.length; i++) {
            totalRewardAmount += bets[winners[i]].amount;
        }

        require(pool >= totalRewardAmount, "Contract does not have enough tokens to distribute");

        if (winners.length > 0) {
            uint256 rewardPerWinner = pool / winners.length;
            for (uint256 i = 0; i < winners.length; i++) {
                require(ghoToken.transfer(winners[i], rewardPerWinner), "Transfer failed");
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

    function getRequestStatus(
        uint256 _requestId
    ) external view returns(bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }
}