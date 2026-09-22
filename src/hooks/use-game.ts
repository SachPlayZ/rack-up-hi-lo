"use client";

import { useCallback, useEffect } from "react";
import {
  useAccount,
  useBalance,
  usePublicClient,
  useReadContract,
  useReadContracts,
  useSignMessage,
  useWatchContractEvent,
  useWriteContract,
} from "wagmi";
import type { Address, Hash } from "viem";
import {
  contractsConfigured,
  faucetAbi,
  faucetAddress,
  gameAddress,
  hiLoGameAbi,
  safeFaucetAddress,
  safeGameAddress,
  type Bet,
  type Player,
  type PlayerView,
  type Round,
  Phase,
  Side,
} from "@/lib/contracts";
import { buildClaimBatch } from "@/lib/claims";

export function useGameSnapshot() {
  const { address, isConnected } = useAccount();
  const account = address ?? "0x0000000000000000000000000000000000000000";
  const enabled = contractsConfigured;

  const gameReads = useReadContracts({
    contracts: [
      { address: safeGameAddress, abi: hiLoGameAbi, functionName: "currentGameId" },
      { address: safeGameAddress, abi: hiLoGameAbi, functionName: "currentRoundId" },
      { address: safeGameAddress, abi: hiLoGameAbi, functionName: "phase" },
      { address: safeGameAddress, abi: hiLoGameAbi, functionName: "currentBall" },
      { address: safeGameAddress, abi: hiLoGameAbi, functionName: "initialRandomnessRequestedAt" },
      { address: safeGameAddress, abi: hiLoGameAbi, functionName: "getCurrentPlayers" },
      { address: safeGameAddress, abi: hiLoGameAbi, functionName: "owner" },
    ],
    query: { enabled, refetchInterval: 4_000 },
  });

  const currentGameId = (gameReads.data?.[0]?.result as bigint | undefined) ?? 1n;
  const currentRoundId = (gameReads.data?.[1]?.result as bigint | undefined) ?? 0n;
  const phase = Number(gameReads.data?.[2]?.result ?? 0) as Phase;
  const currentBall = Number(gameReads.data?.[3]?.result ?? 0);
  const initialRandomnessRequestedAt = (gameReads.data?.[4]?.result as bigint | undefined) ?? 0n;
  const players = (gameReads.data?.[5]?.result as PlayerView[] | undefined) ?? [];
  const owner = gameReads.data?.[6]?.result as Address | undefined;

  const playerRead = useReadContract({
    address: safeGameAddress,
    abi: hiLoGameAbi,
    functionName: "getPlayer",
    args: [currentGameId, account],
    query: { enabled: enabled && isConnected, refetchInterval: 4_000 },
  });

  const roundRead = useReadContract({
    address: safeGameAddress,
    abi: hiLoGameAbi,
    functionName: "getRound",
    args: [currentRoundId],
    query: { enabled: enabled && currentRoundId > 0n, refetchInterval: 2_000 },
  });

  const betRead = useReadContract({
    address: safeGameAddress,
    abi: hiLoGameAbi,
    functionName: "getBet",
    args: [currentRoundId, account],
    query: { enabled: enabled && isConnected && currentRoundId > 0n, refetchInterval: 3_000 },
  });

  const historyRead = useReadContract({
    address: safeGameAddress,
    abi: hiLoGameAbi,
    functionName: "getPlayerBetRounds",
    args: [account],
    query: { enabled: enabled && isConnected, refetchInterval: 5_000 },
  });

  const faucetReads = useReadContracts({
    contracts: [
      { address: safeFaucetAddress, abi: faucetAbi, functionName: "hasClaimed", args: [account] },
      { address: safeFaucetAddress, abi: faucetAbi, functionName: "claimAmount" },
    ],
    query: { enabled: enabled && isConnected, refetchInterval: 5_000 },
  });

  const walletBalance = useBalance({ address, query: { enabled: isConnected, refetchInterval: 5_000 } });
  const faucetBalance = useBalance({ address: faucetAddress, query: { enabled: Boolean(faucetAddress), refetchInterval: 8_000 } });

  const betRounds = (historyRead.data as bigint[] | undefined) ?? [];
  const claimableReads = useReadContracts({
    contracts: betRounds.map((roundId) => ({
      address: safeGameAddress,
      abi: hiLoGameAbi,
      functionName: "getClaimable" as const,
      args: [roundId, account] as const,
    })),
    query: { enabled: enabled && isConnected && betRounds.length > 0, refetchInterval: 5_000 },
  });

  const claimableBatch = buildClaimBatch(
    betRounds,
    (claimableReads.data ?? []).map((item) => (item.result as bigint | undefined) ?? 0n),
  );
  const claimableRounds = claimableBatch.roundIds;
  const claimableTotal = claimableBatch.total;

  const refresh = useCallback(() => {
    void Promise.all([
      gameReads.refetch(),
      playerRead.refetch(),
      roundRead.refetch(),
      betRead.refetch(),
      historyRead.refetch(),
      faucetReads.refetch(),
      claimableReads.refetch(),
      walletBalance.refetch(),
      faucetBalance.refetch(),
    ]);
  }, [betRead, claimableReads, faucetBalance, faucetReads, gameReads, historyRead, playerRead, roundRead, walletBalance]);

  useWatchContractEvent({
    address: gameAddress,
    abi: hiLoGameAbi,
    enabled: Boolean(gameAddress),
    onLogs: refresh,
  });

  useEffect(() => {
    const sync = () => document.visibilityState === "visible" && refresh();
    document.addEventListener("visibilitychange", sync);
    return () => document.removeEventListener("visibilitychange", sync);
  }, [refresh]);

  return {
    configured: contractsConfigured,
    isConnected,
    address,
    currentGameId,
    currentRoundId,
    phase,
    currentBall,
    initialRandomnessRequestedAt,
    players,
    owner,
    player: playerRead.data as Player | undefined,
    round: roundRead.data as Round | undefined,
    bet: betRead.data as Bet | undefined,
    hasClaimedFaucet: Boolean(faucetReads.data?.[0]?.result),
    faucetClaimAmount: faucetReads.data?.[1]?.result as bigint | undefined,
    walletBalance: walletBalance.data?.value,
    faucetBalance: faucetBalance.data?.value,
    claimableRounds,
    claimableTotal,
    isLoading: gameReads.isLoading,
    error: gameReads.error ?? playerRead.error ?? roundRead.error,
    refresh,
  };
}

type GameFunction =
  | "joinLobby"
  | "startGame"
  | "cancelStaleInitialRequest"
  | "placeBet"
  | "requestRoll"
  | "forceRoll"
  | "settleAbandonedRound"
  | "settleTimedOutRound"
  | "openNextRound"
  | "endGame"
  | "claim";

export function useGameActions(refresh: () => void) {
  const publicClient = usePublicClient();
  const { writeContractAsync, isPending } = useWriteContract();

  const send = useCallback(
    async (functionName: GameFunction, args?: readonly unknown[], value?: bigint) => {
      if (!gameAddress) throw new Error("Game contract is not configured.");
      const hash = await writeContractAsync({
        address: gameAddress,
        abi: hiLoGameAbi,
        functionName,
        args,
        value,
      } as never);
      await publicClient?.waitForTransactionReceipt({ hash });
      refresh();
      return hash;
    },
    [publicClient, refresh, writeContractAsync],
  );

  return {
    isPending,
    joinLobby: (displayName: string) => send("joinLobby", [displayName]),
    startGame: () => send("startGame"),
    cancelStaleInitialRequest: () => send("cancelStaleInitialRequest"),
    placeBet: (side: Side, value: bigint) => send("placeBet", [side], value),
    requestRoll: () => send("requestRoll"),
    forceRoll: () => send("forceRoll"),
    settleAbandonedRound: () => send("settleAbandonedRound"),
    settleTimedOutRound: () => send("settleTimedOutRound"),
    openNextRound: () => send("openNextRound"),
    endGame: () => send("endGame"),
    claim: (roundIds: bigint[]) => send("claim", [roundIds]),
  };
}

export function useFaucetClaim(refresh: () => void) {
  const { address } = useAccount();
  const { signMessageAsync } = useSignMessage();

  return useCallback(async (): Promise<Hash> => {
    if (!address) throw new Error("Connect a wallet first.");
    const challengeResponse = await fetch("/api/faucet/challenge", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ address }),
    });
    const challenge = (await challengeResponse.json()) as { message?: string; error?: string };
    if (!challengeResponse.ok || !challenge.message) throw new Error(challenge.error || "Unable to create faucet challenge.");

    const signature = await signMessageAsync({ message: challenge.message });
    const claimResponse = await fetch("/api/faucet/claim", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ message: challenge.message, signature }),
    });
    const claim = (await claimResponse.json()) as { transactionHash?: Hash; error?: string };
    if (!claimResponse.ok) throw new Error(claim.error || "Faucet claim failed.");
    refresh();
    return claim.transactionHash ?? ("0x" as Hash);
  }, [address, refresh, signMessageAsync]);
}
