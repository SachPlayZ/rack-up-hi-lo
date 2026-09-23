// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {HiLoGame} from "contracts/HiLoGame.sol";
import {VRFConsumerBaseV2Plus} from "contracts/vrf/VRFConsumerBaseV2Plus.sol";
import {VRFCoordinatorV2PlusMock} from "contracts/mocks/VRFCoordinatorV2PlusMock.sol";

contract ReentrantClaimer {
    HiLoGame private immutable i_game;
    uint256 private s_roundId;
    bool public reentryBlocked;

    constructor(HiLoGame game) {
        i_game = game;
    }

    receive() external payable {
        uint256[] memory roundIds = new uint256[](1);
        roundIds[0] = s_roundId;
        (bool success,) = address(i_game).call(abi.encodeCall(HiLoGame.claim, (roundIds)));
        reentryBlocked = !success;
    }

    function join() external {
        i_game.joinLobby("Robot");
    }

    function setRoundId(uint256 roundId) external {
        s_roundId = roundId;
    }

    function bet(HiLoGame.Side side) external payable {
        i_game.placeBet{value: msg.value}(side);
    }

    function claim() external {
        uint256[] memory roundIds = new uint256[](1);
        roundIds[0] = s_roundId;
        i_game.claim(roundIds);
    }
}

contract HiLoGameTest is Test {
    uint32 internal constant CALLBACK_GAS_LIMIT = 500_000;
    uint16 internal constant REQUEST_CONFIRMATIONS = 3;

    VRFCoordinatorV2PlusMock internal coordinator;
    HiLoGame internal game;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal outsider = makeAddr("outsider");

    function setUp() public {
        coordinator = new VRFCoordinatorV2PlusMock();
        game = new HiLoGame(
            address(this), address(coordinator), 1, bytes32(uint256(123)), CALLBACK_GAS_LIMIT, REQUEST_CONFIRMATIONS
        );

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(carol, 100 ether);
        vm.deal(outsider, 100 ether);
        _join(alice, "Alice");
        _join(bob, "Bobby");
        _join(carol, "Carol");
    }

    function test_InitialStateAndFrontendReads() external view {
        assertEq(game.currentGameId(), 1);
        assertEq(game.currentRoundId(), 0);
        assertEq(uint256(game.phase()), uint256(HiLoGame.Phase.Lobby));
        assertEq(game.currentBall(), 0);
        assertEq(game.owner(), address(this));

        (uint256 totalPlayers, uint256 activePlayers) = game.getPlayerCount(1);
        assertEq(totalPlayers, 3);
        assertEq(activePlayers, 3);
        HiLoGame.PlayerView[] memory players = game.getPlayerPage(1, 0, 2);
        assertEq(players.length, 2);
        assertEq(players[0].account, alice);
        assertEq(players[0].displayName, "Alice");
        assertTrue(players[0].active);
        HiLoGame.Player memory player = game.getPlayer(1, bob);
        assertTrue(player.joined);
        assertEq(player.displayName, "Bobby");
    }

    function test_RevertWhen_ConstructorOwnerOrCoordinatorIsZero() external {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new HiLoGame(address(0), address(coordinator), 1, bytes32(0), CALLBACK_GAS_LIMIT, REQUEST_CONFIRMATIONS);

        vm.expectRevert(HiLoGame.HiLoGame__ZeroAddress.selector);
        new HiLoGame(address(this), address(0), 1, bytes32(0), CALLBACK_GAS_LIMIT, REQUEST_CONFIRMATIONS);
    }

    function test_RevertWhen_VrfConfigIsInvalid() external {
        vm.expectRevert(HiLoGame.HiLoGame__InvalidVrfConfiguration.selector);
        new HiLoGame(address(this), address(coordinator), 1, bytes32(0), 0, REQUEST_CONFIRMATIONS);

        vm.expectRevert(HiLoGame.HiLoGame__InvalidVrfConfiguration.selector);
        new HiLoGame(address(this), address(coordinator), 1, bytes32(0), CALLBACK_GAS_LIMIT, 0);
    }

    function test_RevertWhen_DisplayNameLengthInvalid() external {
        vm.prank(outsider);
        vm.expectRevert(HiLoGame.HiLoGame__InvalidDisplayName.selector);
        game.joinLobby("ab");

        vm.prank(outsider);
        vm.expectRevert(HiLoGame.HiLoGame__InvalidDisplayName.selector);
        game.joinLobby("abcdefghijklmnopq");
    }

    function test_RevertWhen_PlayerJoinsTwice() external {
        vm.prank(alice);
        vm.expectRevert(HiLoGame.HiLoGame__AlreadyJoined.selector);
        game.joinLobby("Again");
    }

    function test_GameSupportsMoreThanOneHundredPlayersAndPaginatesRoster() external {
        for (uint256 i; i < 105; ++i) {
            // forge-lint: disable-next-line(unsafe-typecast)
            _join(address(uint160(1_000 + i)), "Bot");
        }

        (uint256 totalPlayers, uint256 activePlayers) = game.getPlayerCount(game.currentGameId());
        assertEq(totalPlayers, 108);
        assertEq(activePlayers, 108);
        assertEq(game.getPlayerPage(game.currentGameId(), 0, 100).length, 100);
        assertEq(game.getPlayerPage(game.currentGameId(), 100, 100).length, 8);
        assertEq(game.getPlayerPage(game.currentGameId(), 200, 100).length, 0);
    }

    function test_RevertWhen_PlayerPageSizeIsInvalid() external {
        vm.expectRevert(HiLoGame.HiLoGame__InvalidPlayerPage.selector);
        game.getPlayerPage(1, 0, 0);

        vm.expectRevert(HiLoGame.HiLoGame__InvalidPlayerPage.selector);
        game.getPlayerPage(1, 0, 101);
    }

    function test_RevertWhen_NonOwnerStartsGame() external {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        game.startGame();
    }

    function test_RevertWhen_GameStartsWithFewerThanTwoPlayers() external {
        HiLoGame emptyGame = new HiLoGame(
            address(this), address(coordinator), 1, bytes32(uint256(123)), CALLBACK_GAS_LIMIT, REQUEST_CONFIRMATIONS
        );
        vm.expectRevert(HiLoGame.HiLoGame__NotEnoughPlayers.selector);
        emptyGame.startGame();
    }

    function testFuzz_InitialBallIsAlwaysOneThroughFifteen(uint256 randomWord) external {
        _startGame(randomWord);
        assertGe(game.currentBall(), 1);
        assertLe(game.currentBall(), 15);
        assertEq(uint256(game.phase()), uint256(HiLoGame.Phase.Betting));

        HiLoGame.Round memory round = game.getRound(game.currentRoundId());
        assertEq(round.previousBall, game.currentBall());
        assertEq(round.bettingClosesAt, block.timestamp + game.BETTING_DURATION());
        assertEq(game.BETTING_DURATION(), 60);
    }

    function test_WinnersRemainLosersAndSkippersAreEliminated() external {
        _startGame(7);
        _bet(alice, HiLoGame.Side.Hi, 1 ether);
        _bet(bob, HiLoGame.Side.Lo, 1 ether);
        _requestAndFulfillRoll(13);

        (uint256 totalPlayers, uint256 activePlayers) = game.getPlayerCount(1);
        assertEq(totalPlayers, 3);
        assertEq(activePlayers, 1);
        assertTrue(game.isPlayerActive(1, alice));
        assertFalse(game.isPlayerActive(1, bob));
        assertFalse(game.isPlayerActive(1, carol));
        HiLoGame.PlayerView[] memory players = game.getPlayerPage(1, 0, 3);
        assertTrue(players[0].active);
        assertFalse(players[1].active);
        assertFalse(players[2].active);

        game.openNextRound();
        _bet(alice, HiLoGame.Side.Lo, 1 ether);
        vm.prank(bob);
        vm.expectRevert(HiLoGame.HiLoGame__PlayerEliminated.selector);
        game.placeBet{value: 1 ether}(HiLoGame.Side.Hi);
        vm.prank(carol);
        vm.expectRevert(HiLoGame.HiLoGame__PlayerEliminated.selector);
        game.placeBet{value: 1 ether}(HiLoGame.Side.Hi);
    }

    function test_RefundRoundKeepsAllPlayersActiveIncludingSkippers() external {
        _startGame(7);
        _bet(alice, HiLoGame.Side.Hi, 1 ether);
        _requestAndFulfillRoll(0);

        assertTrue(game.isPlayerActive(1, alice));
        assertTrue(game.isPlayerActive(1, bob));
        assertTrue(game.isPlayerActive(1, carol));
        (, uint256 activePlayers) = game.getPlayerCount(1);
        assertEq(activePlayers, 3);

        game.openNextRound();
        _bet(bob, HiLoGame.Side.Hi, 1 ether);
    }

    function test_EmptyDecisiveRoundEliminatesEveryoneAndCannotAdvance() external {
        _startGame(7);
        _requestAndFulfillRoll(13);

        (, uint256 activePlayers) = game.getPlayerCount(1);
        assertEq(activePlayers, 0);
        vm.expectRevert(HiLoGame.HiLoGame__NoRemainingPlayers.selector);
        game.openNextRound();
        game.endGame();
        assertEq(game.currentGameId(), 2);
    }

    function test_RevertWhen_CallbackCallerIsNotCoordinator() external {
        game.startGame();
        uint256 requestId = game.initialRequestId();
        uint256[] memory words = new uint256[](1);
        words[0] = 7;
        vm.expectRevert(
            abi.encodeWithSelector(
                VRFConsumerBaseV2Plus.VRFConsumerBaseV2Plus__OnlyCoordinatorCanFulfill.selector,
                outsider,
                address(coordinator)
            )
        );
        vm.prank(outsider);
        game.rawFulfillRandomWords(requestId, words);
    }

    function test_PlaceBetUpdatesPoolsBetAndHistory() external {
        _startGame(7);
        uint256 roundId = game.currentRoundId();
        _bet(alice, HiLoGame.Side.Hi, 2 ether);

        HiLoGame.Round memory round = game.getRound(roundId);
        HiLoGame.Bet memory bet = game.getBet(roundId, alice);
        uint256[] memory history = game.getPlayerBetRounds(alice);
        assertEq(round.hiPool, 2 ether);
        assertEq(round.loPool, 0);
        assertEq(round.bettorCount, 1);
        assertEq(bet.amount, 2 ether);
        assertEq(uint256(bet.side), uint256(HiLoGame.Side.Hi));
        assertEq(history.length, 1);
        assertEq(history[0], roundId);
    }

    function test_PlayerBetHistoryPersistsAcrossGames() external {
        _startGame(7);
        _bet(alice, HiLoGame.Side.Hi, 1 ether);
        _requestAndFulfillRoll(13);
        uint256 firstRoundId = game.currentRoundId();
        game.endGame();

        _join(alice, "Alice");
        _join(bob, "Bobby");
        _startGame(7);
        _bet(alice, HiLoGame.Side.Lo, 1 ether);
        uint256 secondRoundId = game.currentRoundId();

        uint256[] memory history = game.getPlayerBetRounds(alice);
        assertEq(history.length, 2);
        assertEq(history[0], firstRoundId);
        assertEq(history[1], secondRoundId);
    }

    function test_RevertWhen_TotalRoundPoolWouldExceedUint128() external {
        _startGame(7);
        vm.deal(alice, uint256(type(uint128).max));
        _bet(alice, HiLoGame.Side.Hi, uint256(type(uint128).max));

        vm.prank(bob);
        vm.expectRevert(HiLoGame.HiLoGame__BetTooLarge.selector);
        game.placeBet{value: 1}(HiLoGame.Side.Lo);
    }

    function test_RevertWhen_BetIsInvalid() external {
        _startGame(7);

        vm.prank(outsider);
        vm.expectRevert(HiLoGame.HiLoGame__NotJoined.selector);
        game.placeBet{value: 1}(HiLoGame.Side.Hi);

        vm.prank(alice);
        vm.expectRevert(HiLoGame.HiLoGame__InvalidSide.selector);
        game.placeBet{value: 1}(HiLoGame.Side.None);

        vm.prank(alice);
        vm.expectRevert(HiLoGame.HiLoGame__ZeroBet.selector);
        game.placeBet(HiLoGame.Side.Hi);

        _bet(alice, HiLoGame.Side.Hi, 1 ether);
        vm.prank(alice);
        vm.expectRevert(HiLoGame.HiLoGame__AlreadyBet.selector);
        game.placeBet{value: 1 ether}(HiLoGame.Side.Lo);
    }

    function test_DeadlineBoundaryRejectsBetAndAllowsOwnerRoll() external {
        _startGame(7);
        HiLoGame.Round memory round = game.getRound(game.currentRoundId());
        vm.warp(round.bettingClosesAt);

        vm.prank(alice);
        vm.expectRevert(HiLoGame.HiLoGame__BettingClosed.selector);
        game.placeBet{value: 1 ether}(HiLoGame.Side.Hi);

        game.requestRoll();
        assertEq(uint256(game.phase()), uint256(HiLoGame.Phase.AwaitingRoll));
    }

    function test_RevertWhen_OwnerRequestsRollBeforeClose() external {
        _startGame(7);
        vm.expectRevert(HiLoGame.HiLoGame__BettingStillOpen.selector);
        game.requestRoll();
    }

    function test_JoinedPlayerCanForceRollAfterFiveMinuteGrace() external {
        _startGame(7);
        HiLoGame.Round memory round = game.getRound(game.currentRoundId());
        vm.warp(uint256(round.bettingClosesAt) + game.FORCE_ROLL_DELAY() - 1);
        vm.prank(alice);
        vm.expectRevert(HiLoGame.HiLoGame__ForceRollTooEarly.selector);
        game.forceRoll();

        vm.warp(block.timestamp + 1);
        vm.prank(alice);
        game.forceRoll();
        assertEq(uint256(game.phase()), uint256(HiLoGame.Phase.AwaitingRoll));
    }

    function test_RevertWhen_NonPlayerForcesRoll() external {
        _startGame(7);
        HiLoGame.Round memory round = game.getRound(game.currentRoundId());
        vm.warp(uint256(round.bettingClosesAt) + game.FORCE_ROLL_DELAY());
        vm.prank(outsider);
        vm.expectRevert(HiLoGame.HiLoGame__NotJoined.selector);
        game.forceRoll();
    }

    function testFuzz_RollNeverRepeatsAndOutcomeMatchesDirection(uint256 initialWord, uint256 rollWord) external {
        _startGame(initialWord);
        uint8 previous = game.currentBall();
        _requestAndFulfillRoll(rollWord);

        HiLoGame.Round memory round = game.getRound(game.currentRoundId());
        assertGe(round.resultBall, 1);
        assertLe(round.resultBall, 15);
        assertTrue(round.resultBall != previous);
        if (round.resultBall > previous) assertEq(uint256(round.outcome), uint256(HiLoGame.Outcome.Hi));
        else assertEq(uint256(round.outcome), uint256(HiLoGame.Outcome.Lo));
    }

    function testFuzz_PariMutuelPayoutConservesEntirePool(uint96 aliceStake, uint96 bobStake, uint96 loserStake)
        external
    {
        aliceStake = uint96(bound(aliceStake, 1, 10 ether));
        bobStake = uint96(bound(bobStake, 1, 10 ether));
        loserStake = uint96(bound(loserStake, 1, 10 ether));
        _startGame(7); // Ball 8.
        _bet(alice, HiLoGame.Side.Hi, aliceStake);
        _bet(bob, HiLoGame.Side.Hi, bobStake);
        _bet(carol, HiLoGame.Side.Lo, loserStake);
        _requestAndFulfillRoll(13); // Candidate 14 -> 15, Hi.

        uint256 roundId = game.currentRoundId();
        uint256 aliceClaimable = game.getClaimable(roundId, alice);
        uint256 bobClaimable = game.getClaimable(roundId, bob);
        uint256 totalPool = uint256(aliceStake) + bobStake + loserStake;
        assertLe(aliceClaimable + bobClaimable, totalPool);

        uint256 aliceBefore = alice.balance;
        _claim(alice, roundId);
        uint256 bobBefore = bob.balance;
        _claim(bob, roundId);
        assertEq((alice.balance - aliceBefore) + (bob.balance - bobBefore), totalPool);
        assertEq(address(game).balance, 0);

        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(HiLoGame.HiLoGame__NothingToClaim.selector, roundId));
        game.claim(_single(roundId));
    }

    function test_LastWinnerReceivesAllRoundingDust() external {
        _startGame(7);
        _bet(alice, HiLoGame.Side.Hi, 1 wei);
        _bet(bob, HiLoGame.Side.Hi, 2 wei);
        _bet(carol, HiLoGame.Side.Lo, 1 wei);
        _requestAndFulfillRoll(13);
        uint256 roundId = game.currentRoundId();

        assertEq(game.getClaimable(roundId, alice), 1);
        _claim(alice, roundId);
        assertEq(game.getClaimable(roundId, bob), 3);
        _claim(bob, roundId);
        assertEq(address(game).balance, 0);
    }

    function test_EmptyWinningSideRefundsEveryBettor() external {
        _startGame(7); // Ball 8.
        _bet(alice, HiLoGame.Side.Hi, 1 ether);
        _bet(bob, HiLoGame.Side.Hi, 2 ether);
        _requestAndFulfillRoll(0); // Ball 1, Lo has no stake.
        uint256 roundId = game.currentRoundId();

        HiLoGame.Round memory round = game.getRound(roundId);
        assertEq(uint256(round.outcome), uint256(HiLoGame.Outcome.Refund));
        assertEq(game.getClaimable(roundId, alice), 1 ether);
        assertEq(game.getClaimable(roundId, bob), 2 ether);
    }

    function test_OracleTimeoutRefundsAndRejectsLateCallback() external {
        _startGame(7);
        _bet(alice, HiLoGame.Side.Hi, 1 ether);
        HiLoGame.Round memory beforeRequest = game.getRound(game.currentRoundId());
        vm.warp(beforeRequest.bettingClosesAt);
        game.requestRoll();
        HiLoGame.Round memory requested = game.getRound(game.currentRoundId());

        vm.warp(uint256(requested.randomnessRequestedAt) + game.ORACLE_TIMEOUT() - 1);
        vm.expectRevert(HiLoGame.HiLoGame__OracleTimeoutNotReached.selector);
        game.settleTimedOutRound();

        vm.warp(block.timestamp + 1);
        game.settleTimedOutRound();
        assertEq(game.getClaimable(game.currentRoundId(), alice), 1 ether);

        vm.expectRevert(HiLoGame.HiLoGame__UnknownRequest.selector);
        coordinator.fulfillRandomWord(requested.requestId, 1);
    }

    function test_UnfundedVrfCannotLockBetsForever() external {
        _startGame(7);
        _bet(alice, HiLoGame.Side.Hi, 1 ether);
        uint256 roundId = game.currentRoundId();
        HiLoGame.Round memory round = game.getRound(roundId);
        vm.warp(round.bettingClosesAt);
        coordinator.setRequestShouldRevert(true);

        vm.expectRevert(VRFCoordinatorV2PlusMock.VRFCoordinatorV2PlusMock__RequestFailed.selector);
        game.requestRoll();
        assertEq(uint256(game.phase()), uint256(HiLoGame.Phase.Betting));

        vm.warp(uint256(round.bettingClosesAt) + game.ORACLE_TIMEOUT() - 1);
        vm.expectRevert(HiLoGame.HiLoGame__OracleTimeoutNotReached.selector);
        game.settleAbandonedRound();

        vm.warp(block.timestamp + 1);
        vm.prank(outsider);
        game.settleAbandonedRound();
        assertEq(uint256(game.phase()), uint256(HiLoGame.Phase.Settled));
        assertEq(game.getClaimable(roundId, alice), 1 ether);
    }

    function test_StaleInitialRequestCanBeCancelledButNotRetried() external {
        game.startGame();
        uint256 requestId = game.initialRequestId();
        vm.warp(block.timestamp + game.ORACLE_TIMEOUT());
        game.cancelStaleInitialRequest();
        assertEq(uint256(game.phase()), uint256(HiLoGame.Phase.Lobby));
        assertEq(game.initialRequestId(), 0);

        vm.expectRevert(HiLoGame.HiLoGame__UnknownRequest.selector);
        coordinator.fulfillRandomWord(requestId, 1);
    }

    function test_DuplicateVrfCallbackFails() external {
        game.startGame();
        uint256 requestId = game.initialRequestId();
        coordinator.fulfillRandomWord(requestId, 7);
        vm.expectRevert(VRFCoordinatorV2PlusMock.VRFCoordinatorV2PlusMock__AlreadyFulfilled.selector);
        coordinator.fulfillRandomWord(requestId, 7);
    }

    function test_OpenNextRoundAndEndGamePreserveOldClaims() external {
        _startGame(7);
        _bet(alice, HiLoGame.Side.Hi, 1 ether);
        _requestAndFulfillRoll(13);
        uint256 oldRoundId = game.currentRoundId();

        game.openNextRound();
        assertEq(game.currentRoundId(), oldRoundId + 1);
        assertEq(game.currentBall(), 15);

        _requestAndFulfillRoll(0);
        game.endGame();
        assertEq(game.currentGameId(), 2);
        assertEq(game.currentRoundId(), 0);
        assertEq(game.currentBall(), 0);
        assertEq(uint256(game.phase()), uint256(HiLoGame.Phase.Lobby));

        _claim(alice, oldRoundId);
        assertEq(address(game).balance, 0);
    }

    function test_ReentrantClaimIsBlockedAndPaidOnce() external {
        ReentrantClaimer attacker = new ReentrantClaimer(game);
        attacker.join();
        _startGame(7);
        uint256 roundId = game.currentRoundId();
        attacker.setRoundId(roundId);
        attacker.bet{value: 1 ether}(HiLoGame.Side.Hi);
        _bet(alice, HiLoGame.Side.Lo, 1 ether);
        _requestAndFulfillRoll(13);

        assertEq(game.getClaimable(roundId, address(attacker)), 2 ether);
        attacker.claim();
        assertEq(address(attacker).balance, 2 ether);
        assertTrue(attacker.reentryBlocked());
    }

    function test_RevertWhen_ClaimBatchIsEmptyOrTooLarge() external {
        vm.expectRevert(HiLoGame.HiLoGame__InvalidClaimBatch.selector);
        game.claim(new uint256[](0));

        vm.expectRevert(HiLoGame.HiLoGame__InvalidClaimBatch.selector);
        game.claim(new uint256[](21));
    }

    function _startGame(uint256 randomWord) internal {
        game.startGame();
        coordinator.fulfillRandomWord(game.initialRequestId(), randomWord);
    }

    function _requestAndFulfillRoll(uint256 randomWord) internal {
        HiLoGame.Round memory round = game.getRound(game.currentRoundId());
        vm.warp(round.bettingClosesAt);
        game.requestRoll();
        round = game.getRound(game.currentRoundId());
        coordinator.fulfillRandomWord(round.requestId, randomWord);
    }

    function _join(address account, string memory name) internal {
        vm.prank(account);
        game.joinLobby(name);
    }

    function _bet(address account, HiLoGame.Side side, uint256 amount) internal {
        vm.prank(account);
        game.placeBet{value: amount}(side);
    }

    function _claim(address account, uint256 roundId) internal {
        vm.prank(account);
        game.claim(_single(roundId));
    }

    function _single(uint256 roundId) internal pure returns (uint256[] memory roundIds) {
        roundIds = new uint256[](1);
        roundIds[0] = roundId;
    }
}
