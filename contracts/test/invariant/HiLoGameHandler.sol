// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {HiLoGame} from "contracts/HiLoGame.sol";
import {VRFCoordinatorV2PlusMock} from "contracts/mocks/VRFCoordinatorV2PlusMock.sol";

contract HiLoGameHandler is Test {
    HiLoGame public immutable game;
    VRFCoordinatorV2PlusMock public immutable coordinator;
    address public immutable owner;

    address[3] internal s_players;
    uint256 public outstandingBalance;
    uint256 public maxRoundSeen;

    constructor(HiLoGame game_, VRFCoordinatorV2PlusMock coordinator_, address owner_) {
        game = game_;
        coordinator = coordinator_;
        owner = owner_;
        s_players = [makeAddr("invariant-alice"), makeAddr("invariant-bob"), makeAddr("invariant-carol")];
        for (uint256 i; i < s_players.length; ++i) {
            vm.deal(s_players[i], type(uint96).max);
        }
    }

    function progress(uint256 randomWord, bool endGame) external {
        HiLoGame.Phase currentPhase = game.phase();
        if (currentPhase == HiLoGame.Phase.Lobby) {
            _joinCurrentLobby();
            vm.prank(owner);
            game.startGame();
        } else if (currentPhase == HiLoGame.Phase.AwaitingInitialBall) {
            coordinator.fulfillRandomWord(game.initialRequestId(), randomWord);
            maxRoundSeen = game.currentRoundId();
        } else if (currentPhase == HiLoGame.Phase.Betting) {
            HiLoGame.Round memory round = game.getRound(game.currentRoundId());
            vm.warp(round.bettingClosesAt);
            vm.prank(owner);
            game.requestRoll();
        } else if (currentPhase == HiLoGame.Phase.AwaitingRoll) {
            HiLoGame.Round memory round = game.getRound(game.currentRoundId());
            coordinator.fulfillRandomWord(round.requestId, randomWord);
        } else if (endGame) {
            vm.prank(owner);
            game.endGame();
        } else {
            vm.prank(owner);
            game.openNextRound();
            maxRoundSeen = game.currentRoundId();
        }
    }

    function bet(uint256 playerSeed, uint96 rawAmount, bool high) external {
        if (game.phase() != HiLoGame.Phase.Betting) return;
        uint256 roundId = game.currentRoundId();
        HiLoGame.Round memory round = game.getRound(roundId);
        if (block.timestamp >= round.bettingClosesAt) return;

        address account = s_players[playerSeed % s_players.length];
        HiLoGame.Bet memory existing = game.getBet(roundId, account);
        if (existing.amount != 0) return;

        uint256 amount = uint256(rawAmount) % 10 ether + 1;
        vm.prank(account);
        game.placeBet{value: amount}(high ? HiLoGame.Side.Hi : HiLoGame.Side.Lo);
        outstandingBalance += amount;
        maxRoundSeen = roundId;
    }

    function claim(uint256 playerSeed, uint256 roundSeed) external {
        if (maxRoundSeen == 0) return;
        address account = s_players[playerSeed % s_players.length];
        uint256 roundId = roundSeed % maxRoundSeen + 1;
        uint256 payout = game.getClaimable(roundId, account);
        if (payout == 0) return;

        uint256[] memory ids = new uint256[](1);
        ids[0] = roundId;
        vm.prank(account);
        game.claim(ids);
        outstandingBalance -= payout;
    }

    function playerAt(uint256 index) external view returns (address account) {
        account = s_players[index];
    }

    function _joinCurrentLobby() private {
        for (uint256 i; i < s_players.length; ++i) {
            vm.prank(s_players[i]);
            game.joinLobby(i == 0 ? "Alice" : i == 1 ? "Bobby" : "Carol");
        }
    }
}
