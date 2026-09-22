import { isAddress, parseAbi, zeroAddress, type Address } from "viem";

export enum Phase {
  Lobby,
  AwaitingInitialBall,
  Betting,
  AwaitingRoll,
  Settled,
}

export enum Side {
  None,
  Hi,
  Lo,
}

export enum Outcome {
  Pending,
  Hi,
  Lo,
  Refund,
}

export type PlayerView = { account: Address; displayName: string };
export type Player = { displayName: string; joined: boolean };
export type Bet = { amount: bigint; side: Side; claimed: boolean };
export type Round = {
  gameId: bigint;
  requestId: bigint;
  hiPool: bigint;
  loPool: bigint;
  eligibleStakeRemaining: bigint;
  payoutPoolRemaining: bigint;
  bettingClosesAt: bigint;
  randomnessRequestedAt: bigint;
  bettorCount: number;
  previousBall: number;
  resultBall: number;
  outcome: Outcome;
};

export const hiLoGameAbi = parseAbi([
  "function owner() view returns (address)",
  "function currentGameId() view returns (uint256)",
  "function currentRoundId() view returns (uint256)",
  "function phase() view returns (uint8)",
  "function currentBall() view returns (uint8)",
  "function initialRandomnessRequestedAt() view returns (uint64)",
  "function getCurrentPlayers() view returns ((address account,string displayName)[])",
  "function getRound(uint256 roundId) view returns ((uint256 gameId,uint256 requestId,uint128 hiPool,uint128 loPool,uint128 eligibleStakeRemaining,uint128 payoutPoolRemaining,uint64 bettingClosesAt,uint64 randomnessRequestedAt,uint32 bettorCount,uint8 previousBall,uint8 resultBall,uint8 outcome))",
  "function getPlayer(uint256 gameId,address account) view returns ((string displayName,bool joined))",
  "function getBet(uint256 roundId,address account) view returns ((uint128 amount,uint8 side,bool claimed))",
  "function getClaimable(uint256 roundId,address account) view returns (uint256)",
  "function getPlayerBetRounds(address account) view returns (uint256[])",
  "function joinLobby(string displayName)",
  "function startGame()",
  "function cancelStaleInitialRequest()",
  "function placeBet(uint8 side) payable",
  "function requestRoll()",
  "function forceRoll()",
  "function settleAbandonedRound()",
  "function settleTimedOutRound()",
  "function openNextRound()",
  "function endGame()",
  "function claim(uint256[] roundIds)",
  "event LobbyJoined(uint256 indexed gameId,address indexed player,string displayName,uint256 playerCount)",
  "event GameStarted(uint256 indexed gameId,uint8 initialBall,uint256 indexed firstRoundId)",
  "event GameEnded(uint256 indexed gameId,uint256 indexed nextGameId)",
  "event RandomnessRequested(uint256 indexed requestId,uint256 indexed gameId,uint256 indexed roundId,uint8 kind)",
  "event InitialRandomnessCancelled(uint256 indexed gameId,uint256 indexed requestId)",
  "event BetPlaced(uint256 indexed roundId,address indexed player,uint8 side,uint256 amount)",
  "event RoundOpened(uint256 indexed gameId,uint256 indexed roundId,uint8 previousBall,uint64 bettingClosesAt)",
  "event RoundSettled(uint256 indexed gameId,uint256 indexed roundId,uint8 outcome,uint8 previousBall,uint8 resultBall,uint256 hiPool,uint256 loPool)",
  "event RoundRefunded(uint256 indexed gameId,uint256 indexed roundId,uint256 indexed requestId)",
  "event RoundAbandoned(uint256 indexed gameId,uint256 indexed roundId)",
  "event Claimed(address indexed player,uint256 indexed roundId,uint256 amount)",
]);

export const faucetAbi = parseAbi([
  "function hasClaimed(address account) view returns (bool)",
  "function claimAmount() view returns (uint256)",
  "function relayer() view returns (address)",
  "function claimFor(address recipient)",
]);

function envAddress(value: string | undefined): Address | undefined {
  return value && isAddress(value) ? value : undefined;
}

export const gameAddress = envAddress(process.env.NEXT_PUBLIC_GAME_ADDRESS);
export const faucetAddress = envAddress(process.env.NEXT_PUBLIC_FAUCET_ADDRESS);
export const safeGameAddress = gameAddress ?? zeroAddress;
export const safeFaucetAddress = faucetAddress ?? zeroAddress;
export const contractsConfigured = Boolean(gameAddress && faucetAddress);

export const phaseLabel: Record<Phase, string> = {
  [Phase.Lobby]: "Lobby open",
  [Phase.AwaitingInitialBall]: "Drawing opener",
  [Phase.Betting]: "Betting live",
  [Phase.AwaitingRoll]: "Ball in motion",
  [Phase.Settled]: "Round settled",
};
