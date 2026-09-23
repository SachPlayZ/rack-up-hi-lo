// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";
import {HiLoGame} from "contracts/HiLoGame.sol";
import {VRFCoordinatorV2PlusMock} from "contracts/mocks/VRFCoordinatorV2PlusMock.sol";
import {HiLoGameHandler} from "test/invariant/HiLoGameHandler.sol";

contract HiLoGameInvariantTest is StdInvariant, Test {
    HiLoGame internal game;
    VRFCoordinatorV2PlusMock internal coordinator;
    HiLoGameHandler internal handler;

    function setUp() public {
        coordinator = new VRFCoordinatorV2PlusMock();
        game = new HiLoGame(address(this), address(coordinator), 1, bytes32(uint256(123)), 500_000, 3);
        handler = new HiLoGameHandler(game, coordinator, address(this));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = handler.progress.selector;
        selectors[1] = handler.bet.selector;
        selectors[2] = handler.claim.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_ContractBalanceEqualsTrackedUnclaimedValue() external view {
        assertEq(address(game).balance, handler.outstandingBalance());
    }

    function invariant_CurrentBallIsZeroOrValidPoolBall() external view {
        uint8 ball = game.currentBall();
        assertTrue(ball == 0 || (ball >= 1 && ball <= 15));
        if (game.phase() == HiLoGame.Phase.Lobby || game.phase() == HiLoGame.Phase.AwaitingInitialBall) {
            assertEq(ball, 0);
        }
    }

    function invariant_ActivePlayersNeverExceedJoinedPlayers() external view {
        (uint256 totalPlayers, uint256 activePlayers) = game.getPlayerCount(game.currentGameId());
        assertLe(activePlayers, totalPlayers);
    }

    function invariant_RoundAccountingNeverExceedsOriginalPool() external view {
        uint256 maxRound = handler.maxRoundSeen();
        for (uint256 roundId = 1; roundId <= maxRound; ++roundId) {
            HiLoGame.Round memory round = game.getRound(roundId);
            uint256 totalPool = uint256(round.hiPool) + round.loPool;
            assertLe(round.payoutPoolRemaining, totalPool);
            assertLe(round.eligibleStakeRemaining, totalPool);
            assertTrue(round.previousBall >= 1 && round.previousBall <= 15);
            if (round.resultBall != 0) {
                assertTrue(round.resultBall >= 1 && round.resultBall <= 15);
                assertTrue(round.resultBall != round.previousBall);
            }
        }
    }
}
