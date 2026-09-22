// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Ownable2Step} from "openzeppelin-contracts/access/Ownable2Step.sol";
import {ReentrancyGuardTransient} from "openzeppelin-contracts/utils/ReentrancyGuardTransient.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IVRFCoordinatorV2Plus} from "contracts/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFV2PlusClient} from "contracts/libraries/VRFV2PlusClient.sol";
import {VRFConsumerBaseV2Plus} from "contracts/vrf/VRFConsumerBaseV2Plus.sol";

/**
 * @title HiLoGame
 * @notice Onchain, pari-mutuel Hi-Lo rounds using Chainlink VRF v2.5.
 * @custom:security-contact security@hi-lo.game
 */
contract HiLoGame is Ownable2Step, ReentrancyGuardTransient, VRFConsumerBaseV2Plus {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                              TYPES
    //////////////////////////////////////////////////////////////*/

    enum Phase {
        Lobby,
        AwaitingInitialBall,
        Betting,
        AwaitingRoll,
        Settled
    }

    enum Side {
        None,
        Hi,
        Lo
    }

    enum Outcome {
        Pending,
        Hi,
        Lo,
        Refund
    }

    enum RequestKind {
        None,
        InitialBall,
        Roll
    }

    struct Player {
        string displayName;
        bool joined;
    }

    struct PlayerView {
        address account;
        string displayName;
    }

    struct Bet {
        uint128 amount;
        Side side;
        bool claimed;
    }

    struct Round {
        uint256 gameId;
        uint256 requestId;
        uint128 hiPool;
        uint128 loPool;
        uint128 eligibleStakeRemaining;
        uint128 payoutPoolRemaining;
        uint64 bettingClosesAt;
        uint64 randomnessRequestedAt;
        uint32 bettorCount;
        uint8 previousBall;
        uint8 resultBall;
        Outcome outcome;
    }

    struct RandomnessRequest {
        uint256 roundId;
        RequestKind kind;
    }

    /*//////////////////////////////////////////////////////////////
                         STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BETTING_DURATION = 30 seconds;
    uint256 public constant FORCE_ROLL_DELAY = 5 minutes;
    uint256 public constant ORACLE_TIMEOUT = 1 hours;
    uint256 public constant MAX_PLAYERS = 100;
    uint256 public constant MAX_BATCH_CLAIMS = 20;

    uint32 private constant NUM_WORDS = 1;
    uint8 private constant MIN_BALL = 1;
    uint8 private constant MAX_BALL = 15;

    IVRFCoordinatorV2Plus public immutable coordinator;
    uint256 public immutable subscriptionId;
    bytes32 public immutable keyHash;
    uint32 public immutable callbackGasLimit;
    uint16 public immutable requestConfirmations;

    uint256 public currentGameId;
    uint256 public currentRoundId;
    Phase public phase;
    uint8 public currentBall;

    uint256 public initialRequestId;
    uint64 public initialRandomnessRequestedAt;

    uint256 private s_lastRoundId;
    mapping(uint256 gameId => address[] accounts) private s_playersByGame;
    mapping(uint256 gameId => mapping(address account => Player player)) private s_players;
    mapping(uint256 roundId => Round round) private s_rounds;
    mapping(uint256 roundId => mapping(address account => Bet bet)) private s_bets;
    mapping(address account => uint256[] roundIds) private s_playerBetRounds;
    mapping(uint256 requestId => RandomnessRequest request) private s_requests;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event LobbyJoined(uint256 indexed gameId, address indexed player, string displayName, uint256 playerCount);
    event GameStarted(uint256 indexed gameId, uint8 initialBall, uint256 indexed firstRoundId);
    event GameEnded(uint256 indexed gameId, uint256 indexed nextGameId);
    event RandomnessRequested(
        uint256 indexed requestId, uint256 indexed gameId, uint256 indexed roundId, RequestKind kind
    );
    event InitialRandomnessCancelled(uint256 indexed gameId, uint256 indexed requestId);
    event RoundOpened(uint256 indexed gameId, uint256 indexed roundId, uint8 previousBall, uint64 bettingClosesAt);
    event BetPlaced(uint256 indexed roundId, address indexed player, Side side, uint256 amount);
    event RoundSettled(
        uint256 indexed gameId,
        uint256 indexed roundId,
        Outcome outcome,
        uint8 previousBall,
        uint8 resultBall,
        uint256 hiPool,
        uint256 loPool
    );
    event RoundRefunded(uint256 indexed gameId, uint256 indexed roundId, uint256 indexed requestId);
    event RoundAbandoned(uint256 indexed gameId, uint256 indexed roundId);
    event Claimed(address indexed player, uint256 indexed roundId, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error HiLoGame__ZeroAddress();
    error HiLoGame__InvalidVrfConfiguration();
    error HiLoGame__WrongPhase(Phase expected, Phase actual);
    error HiLoGame__InvalidDisplayName();
    error HiLoGame__AlreadyJoined();
    error HiLoGame__LobbyFull();
    error HiLoGame__NotEnoughPlayers();
    error HiLoGame__NotJoined();
    error HiLoGame__InvalidSide();
    error HiLoGame__ZeroBet();
    error HiLoGame__BetTooLarge();
    error HiLoGame__AlreadyBet();
    error HiLoGame__BettingClosed();
    error HiLoGame__BettingStillOpen();
    error HiLoGame__ForceRollTooEarly();
    error HiLoGame__OracleTimeoutNotReached();
    error HiLoGame__UnknownRequest();
    error HiLoGame__InvalidRandomWords();
    error HiLoGame__InvalidClaimBatch();
    error HiLoGame__NothingToClaim(uint256 roundId);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address initialOwner,
        address vrfCoordinator,
        uint256 vrfSubscriptionId,
        bytes32 vrfKeyHash,
        uint32 vrfCallbackGasLimit,
        uint16 vrfRequestConfirmations
    ) Ownable(initialOwner) VRFConsumerBaseV2Plus(vrfCoordinator) {
        if (initialOwner == address(0) || vrfCoordinator == address(0)) {
            revert HiLoGame__ZeroAddress();
        }
        if (vrfCallbackGasLimit == 0 || vrfRequestConfirmations == 0) {
            revert HiLoGame__InvalidVrfConfiguration();
        }

        coordinator = IVRFCoordinatorV2Plus(vrfCoordinator);
        subscriptionId = vrfSubscriptionId;
        keyHash = vrfKeyHash;
        callbackGasLimit = vrfCallbackGasLimit;
        requestConfirmations = vrfRequestConfirmations;
        currentGameId = 1;
    }

    /*//////////////////////////////////////////////////////////////
                   USER-FACING STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function joinLobby(string calldata displayName) external {
        _requirePhase(Phase.Lobby);
        bytes calldata nameBytes = bytes(displayName);
        if (nameBytes.length < 3 || nameBytes.length > 16) revert HiLoGame__InvalidDisplayName();

        uint256 gameId = currentGameId;
        if (s_players[gameId][msg.sender].joined) revert HiLoGame__AlreadyJoined();
        address[] storage accounts = s_playersByGame[gameId];
        if (accounts.length >= MAX_PLAYERS) revert HiLoGame__LobbyFull();

        s_players[gameId][msg.sender] = Player({displayName: displayName, joined: true});
        accounts.push(msg.sender);

        emit LobbyJoined(gameId, msg.sender, displayName, accounts.length);
    }

    function startGame() external onlyOwner {
        _requirePhase(Phase.Lobby);
        uint256 gameId = currentGameId;
        if (s_playersByGame[gameId].length < 2) revert HiLoGame__NotEnoughPlayers();

        phase = Phase.AwaitingInitialBall;
        initialRandomnessRequestedAt = uint64(block.timestamp);
        uint256 requestId = _requestRandomness();
        initialRequestId = requestId;
        s_requests[requestId] = RandomnessRequest({roundId: 0, kind: RequestKind.InitialBall});

        emit RandomnessRequested(requestId, gameId, 0, RequestKind.InitialBall);
    }

    function placeBet(Side side) external payable {
        _requirePhase(Phase.Betting);
        if (side != Side.Hi && side != Side.Lo) revert HiLoGame__InvalidSide();
        if (msg.value == 0) revert HiLoGame__ZeroBet();
        if (msg.value > type(uint128).max) revert HiLoGame__BetTooLarge();

        uint256 gameId = currentGameId;
        if (!s_players[gameId][msg.sender].joined) revert HiLoGame__NotJoined();

        uint256 roundId = currentRoundId;
        Round storage round = s_rounds[roundId];
        if (block.timestamp >= round.bettingClosesAt) revert HiLoGame__BettingClosed();
        Bet storage bet = s_bets[roundId][msg.sender];
        if (bet.amount != 0) revert HiLoGame__AlreadyBet();

        uint128 amount = uint128(msg.value);
        uint256 existingPool = uint256(round.hiPool) + round.loPool;
        if (amount > type(uint128).max - existingPool) revert HiLoGame__BetTooLarge();
        bet.amount = amount;
        bet.side = side;
        if (side == Side.Hi) round.hiPool += amount;
        else round.loPool += amount;
        ++round.bettorCount;
        s_playerBetRounds[msg.sender].push(roundId);

        emit BetPlaced(roundId, msg.sender, side, amount);
    }

    function requestRoll() external onlyOwner {
        _requirePhase(Phase.Betting);
        Round storage round = s_rounds[currentRoundId];
        if (block.timestamp < round.bettingClosesAt) revert HiLoGame__BettingStillOpen();
        _requestRoll(round);
    }

    function forceRoll() external {
        _requirePhase(Phase.Betting);
        uint256 gameId = currentGameId;
        if (!s_players[gameId][msg.sender].joined) revert HiLoGame__NotJoined();

        Round storage round = s_rounds[currentRoundId];
        if (block.timestamp < uint256(round.bettingClosesAt) + FORCE_ROLL_DELAY) {
            revert HiLoGame__ForceRollTooEarly();
        }
        _requestRoll(round);
    }

    function cancelStaleInitialRequest() external onlyOwner {
        _requirePhase(Phase.AwaitingInitialBall);
        if (block.timestamp < uint256(initialRandomnessRequestedAt) + ORACLE_TIMEOUT) {
            revert HiLoGame__OracleTimeoutNotReached();
        }

        uint256 requestId = initialRequestId;
        delete s_requests[requestId];
        initialRequestId = 0;
        initialRandomnessRequestedAt = 0;
        phase = Phase.Lobby;

        emit InitialRandomnessCancelled(currentGameId, requestId);
    }

    function settleTimedOutRound() external {
        _requirePhase(Phase.AwaitingRoll);
        Round storage round = s_rounds[currentRoundId];
        if (block.timestamp < uint256(round.randomnessRequestedAt) + ORACLE_TIMEOUT) {
            revert HiLoGame__OracleTimeoutNotReached();
        }

        uint256 requestId = round.requestId;
        delete s_requests[requestId];
        _settleRefund(round);

        emit RoundRefunded(round.gameId, currentRoundId, requestId);
    }

    function settleAbandonedRound() external {
        _requirePhase(Phase.Betting);
        Round storage round = s_rounds[currentRoundId];
        if (block.timestamp < uint256(round.bettingClosesAt) + ORACLE_TIMEOUT) {
            revert HiLoGame__OracleTimeoutNotReached();
        }

        _settleRefund(round);
        emit RoundAbandoned(round.gameId, currentRoundId);
    }

    function openNextRound() external onlyOwner {
        _requirePhase(Phase.Settled);
        _openRound();
    }

    function endGame() external onlyOwner {
        _requirePhase(Phase.Settled);
        uint256 endedGameId = currentGameId;
        currentGameId = endedGameId + 1;
        currentRoundId = 0;
        currentBall = 0;
        phase = Phase.Lobby;

        emit GameEnded(endedGameId, currentGameId);
    }

    function claim(uint256[] calldata roundIds) external nonReentrant {
        if (roundIds.length == 0 || roundIds.length > MAX_BATCH_CLAIMS) {
            revert HiLoGame__InvalidClaimBatch();
        }

        uint256 totalPayout;
        for (uint256 i; i < roundIds.length; ++i) {
            uint256 roundId = roundIds[i];
            uint256 payout = _claim(roundId, msg.sender);
            totalPayout += payout;
            emit Claimed(msg.sender, roundId, payout);
        }

        msg.sender.safeTransferETH(totalPayout);
    }

    /*//////////////////////////////////////////////////////////////
                    USER-FACING READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getCurrentPlayers() external view returns (PlayerView[] memory playerList) {
        uint256 gameId = currentGameId;
        address[] storage accounts = s_playersByGame[gameId];
        playerList = new PlayerView[](accounts.length);
        for (uint256 i; i < accounts.length; ++i) {
            address account = accounts[i];
            playerList[i] = PlayerView({account: account, displayName: s_players[gameId][account].displayName});
        }
    }

    function getPlayer(uint256 gameId, address account) external view returns (Player memory player) {
        player = s_players[gameId][account];
    }

    function getRound(uint256 roundId) external view returns (Round memory round) {
        round = s_rounds[roundId];
    }

    function getBet(uint256 roundId, address account) external view returns (Bet memory bet) {
        bet = s_bets[roundId][account];
    }

    function getPlayerBetRounds(address account) external view returns (uint256[] memory roundIds) {
        roundIds = s_playerBetRounds[account];
    }

    function getClaimable(uint256 roundId, address account) public view returns (uint256 payout) {
        Round storage round = s_rounds[roundId];
        Bet storage bet = s_bets[roundId][account];
        if (!_isEligible(round.outcome, bet) || bet.claimed) return 0;

        if (bet.amount == round.eligibleStakeRemaining) return round.payoutPoolRemaining;
        uint256 totalPool = uint256(round.hiPool) + round.loPool;
        uint256 originalEligibleStake =
            round.outcome == Outcome.Refund ? totalPool : round.outcome == Outcome.Hi ? round.hiPool : round.loPool;
        payout = uint256(bet.amount) * totalPool / originalEligibleStake;
    }

    function getRequest(uint256 requestId) external view returns (RandomnessRequest memory request) {
        request = s_requests[requestId];
    }

    /*//////////////////////////////////////////////////////////////
                     INTERNAL STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        RandomnessRequest memory request = s_requests[requestId];
        if (request.kind == RequestKind.None) revert HiLoGame__UnknownRequest();
        if (randomWords.length == 0) revert HiLoGame__InvalidRandomWords();
        delete s_requests[requestId];

        if (request.kind == RequestKind.InitialBall) {
            _fulfillInitialBall(requestId, randomWords[0]);
        } else {
            _fulfillRoll(request.roundId, randomWords[0]);
        }
    }

    function _fulfillInitialBall(uint256 requestId, uint256 randomWord) private {
        if (phase != Phase.AwaitingInitialBall || requestId != initialRequestId) {
            revert HiLoGame__UnknownRequest();
        }

        // Casting is safe because the modulo result is at most 14.
        // forge-lint: disable-next-line(unsafe-typecast)
        currentBall = uint8(randomWord % MAX_BALL) + MIN_BALL;
        initialRequestId = 0;
        initialRandomnessRequestedAt = 0;
        _openRound();

        emit GameStarted(currentGameId, currentBall, currentRoundId);
    }

    function _fulfillRoll(uint256 roundId, uint256 randomWord) private {
        if (phase != Phase.AwaitingRoll || roundId != currentRoundId) revert HiLoGame__UnknownRequest();
        Round storage round = s_rounds[roundId];

        // Casting is safe because the modulo result is at most 13.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 resultBall = uint8(randomWord % (MAX_BALL - MIN_BALL)) + MIN_BALL;
        if (resultBall >= round.previousBall) ++resultBall;

        round.resultBall = resultBall;
        currentBall = resultBall;

        Outcome result = resultBall > round.previousBall ? Outcome.Hi : Outcome.Lo;
        uint128 totalPool = round.hiPool + round.loPool;
        uint128 winningPool = result == Outcome.Hi ? round.hiPool : round.loPool;
        if (totalPool != 0 && winningPool == 0) {
            round.outcome = Outcome.Refund;
            round.eligibleStakeRemaining = totalPool;
        } else {
            round.outcome = result;
            round.eligibleStakeRemaining = winningPool;
        }
        round.payoutPoolRemaining = totalPool;
        phase = Phase.Settled;

        emit RoundSettled(
            round.gameId, roundId, round.outcome, round.previousBall, resultBall, round.hiPool, round.loPool
        );
    }

    function _settleRefund(Round storage round) private {
        uint128 totalPool = round.hiPool + round.loPool;
        round.outcome = Outcome.Refund;
        round.eligibleStakeRemaining = totalPool;
        round.payoutPoolRemaining = totalPool;
        phase = Phase.Settled;
    }

    function _openRound() private {
        uint256 roundId = ++s_lastRoundId;
        currentRoundId = roundId;
        // Casting is safe for all timestamps representable by this chain for the contract's lifetime.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint64 closesAt = uint64(block.timestamp + BETTING_DURATION);
        s_rounds[roundId] = Round({
            gameId: currentGameId,
            requestId: 0,
            hiPool: 0,
            loPool: 0,
            eligibleStakeRemaining: 0,
            payoutPoolRemaining: 0,
            bettingClosesAt: closesAt,
            randomnessRequestedAt: 0,
            bettorCount: 0,
            previousBall: currentBall,
            resultBall: 0,
            outcome: Outcome.Pending
        });
        phase = Phase.Betting;

        emit RoundOpened(currentGameId, roundId, currentBall, closesAt);
    }

    function _requestRoll(Round storage round) private {
        phase = Phase.AwaitingRoll;
        round.randomnessRequestedAt = uint64(block.timestamp);
        uint256 requestId = _requestRandomness();
        round.requestId = requestId;
        s_requests[requestId] = RandomnessRequest({roundId: currentRoundId, kind: RequestKind.Roll});

        emit RandomnessRequested(requestId, currentGameId, currentRoundId, RequestKind.Roll);
    }

    function _requestRandomness() private returns (uint256 requestId) {
        requestId = coordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
    }

    function _claim(uint256 roundId, address account) private returns (uint256 payout) {
        payout = getClaimable(roundId, account);
        if (payout == 0) revert HiLoGame__NothingToClaim(roundId);

        Round storage round = s_rounds[roundId];
        Bet storage bet = s_bets[roundId][account];
        bet.claimed = true;
        round.eligibleStakeRemaining -= bet.amount;
        // Casting is safe because payoutPoolRemaining and the total round pool are uint128-bounded.
        // forge-lint: disable-next-line(unsafe-typecast)
        round.payoutPoolRemaining -= uint128(payout);
    }

    /*//////////////////////////////////////////////////////////////
                      INTERNAL READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _requirePhase(Phase expected) private view {
        Phase actual = phase;
        if (actual != expected) revert HiLoGame__WrongPhase(expected, actual);
    }

    function _isEligible(Outcome outcome, Bet storage bet) private view returns (bool eligible) {
        if (bet.amount == 0 || outcome == Outcome.Pending) return false;
        if (outcome == Outcome.Refund) return true;
        eligible = (outcome == Outcome.Hi && bet.side == Side.Hi) || (outcome == Outcome.Lo && bet.side == Side.Lo);
    }
}
