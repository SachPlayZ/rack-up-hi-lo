"use client";

import { useMemo, useState } from "react";
import { parseEther } from "viem";
import { Countdown } from "@/components/countdown";
import { PoolBall } from "@/components/pool-ball";
import { SiteHeader } from "@/components/site-header";
import { useFaucetClaim, useGameActions, useGameSnapshot } from "@/hooks/use-game";
import { Outcome, Phase, phaseLabel, Side } from "@/lib/contracts";
import { errorMessage, formatEth, shortAddress } from "@/lib/format";
import { usePrivyAuth } from "@/hooks/use-privy-auth";

type Feedback = { tone: "idle" | "pending" | "success" | "error"; message: string };

const hero: Record<Phase, { eyebrow: string; title: string; body: string }> = {
  [Phase.Lobby]: {
    eyebrow: "The table is open",
    title: "Pick a name. Take your shot.",
    body: "Claim test ETH, choose a name, and join the next live Hi-Lo game.",
  },
  [Phase.AwaitingInitialBall]: {
    eyebrow: "Game on",
    title: "The opening ball is coming.",
    body: "Chainlink VRF is choosing the number that every call will chase.",
  },
  [Phase.Betting]: {
    eyebrow: "One minute on the clock",
    title: "Higher or lower? Call it.",
    body: "Pick the right side to stay in. Winning wagers split the whole table.",
  },
  [Phase.AwaitingRoll]: {
    eyebrow: "No more bets",
    title: "The next ball is in motion.",
    body: "The result is verifiably random and cannot repeat the current ball.",
  },
  [Phase.Settled]: {
    eyebrow: "Round complete",
    title: "Read the table. Rack again.",
    body: "Correct picks stay in the game. Claim your winnings whenever you like.",
  },
};

export function GameRoom() {
  const snapshot = useGameSnapshot();
  const actions = useGameActions(snapshot.refresh);
  const claimFaucet = useFaucetClaim(snapshot.refresh);
  const { authenticated, ready: privyReady, connectOrCreateWallet } = usePrivyAuth();
  const [displayName, setDisplayName] = useState("");
  const [amount, setAmount] = useState("0.0001");
  const [feedback, setFeedback] = useState<Feedback>({ tone: "idle", message: "" });
  const copy = hero[snapshot.phase];
  const round = snapshot.round;
  const bet = snapshot.bet;
  const isRolling = snapshot.phase === Phase.AwaitingInitialBall || snapshot.phase === Phase.AwaitingRoll;
  const shownBall = snapshot.phase === Phase.Settled && round?.resultBall ? round.resultBall : snapshot.currentBall;
  const hasWalletFunds = (snapshot.walletBalance ?? 0n) > 0n;
  const canEnterName = snapshot.isConnected && snapshot.phase === Phase.Lobby && !snapshot.player?.joined;

  const caption = useMemo(() => {
    if (snapshot.phase === Phase.Lobby) return "Waiting for the first rack";
    if (snapshot.phase === Phase.AwaitingInitialBall) return "Verifiable opening draw";
    if (snapshot.phase === Phase.AwaitingRoll) return "Chainlink VRF is settling the shot";
    if (snapshot.phase === Phase.Settled && round) {
      if (round.outcome === Outcome.Refund) return "No winning pool — all wagers refunded";
      return `${round.outcome === Outcome.Hi ? "Hi" : "Lo"} wins · ${round.previousBall} → ${round.resultBall}`;
    }
    return `Ball ${snapshot.currentBall} sets the line`;
  }, [round, snapshot.currentBall, snapshot.phase]);

  async function run(label: string, task: () => Promise<unknown>) {
    setFeedback({ tone: "pending", message: label });
    try {
      await task();
      setFeedback({ tone: "success", message: "Confirmed on Base Sepolia." });
    } catch (error) {
      setFeedback({ tone: "error", message: errorMessage(error) });
    }
  }

  function submitName(event: React.FormEvent) {
    event.preventDefault();
    const name = displayName.trim();
    if (!/^[A-Za-z0-9 _-]{3,16}$/.test(name)) {
      setFeedback({ tone: "error", message: "Use 3–16 letters, numbers, spaces, underscores, or hyphens." });
      return;
    }
    void run("Joining the game…", () => actions.joinLobby(name));
  }

  function placeBet(side: Side) {
    let value: bigint;
    try {
      value = parseEther(amount);
      if (value <= 0n) throw new Error();
    } catch {
      setFeedback({ tone: "error", message: "Enter a valid ETH amount." });
      return;
    }
    void run(`Putting ${amount} ETH on ${side === Side.Hi ? "Hi" : "Lo"}…`, () => actions.placeBet(side, value));
  }

  return (
    <div className="app-shell">
      <SiteHeader />
      <main className="main-grid">
        <section className="hero-copy">
          <p className="eyebrow">{copy.eyebrow}</p>
          <h1>{copy.title}</h1>
          <p>{copy.body}</p>
        </section>

        <section className="table-card" aria-label="Current Hi-Lo round">
          <div className="table-card__top">
            <div>
              <div className="round-label">Game {snapshot.currentGameId.toString()} · Round {snapshot.currentRoundId.toString()}</div>
              <div className={`status-pill${isRolling ? " status-pill--warning" : ""}`}>{phaseLabel[snapshot.phase]}</div>
            </div>
            {snapshot.phase === Phase.Betting && round ? <Countdown deadline={round.bettingClosesAt} /> : null}
          </div>

          <div className="ball-stage">
            <div>
              <PoolBall number={shownBall} rolling={isRolling} />
              <p className="ball-caption">{caption}</p>
            </div>
          </div>

          <div className="pool-grid" aria-label="Betting pools">
            <div className="pool-tile">
              <span>Hi pool</span>
              <strong>{formatEth(round?.hiPool)} ETH</strong>
            </div>
            <div className="pool-tile">
              <span>Lo pool</span>
              <strong>{formatEth(round?.loPool)} ETH</strong>
            </div>
          </div>
          <div className="pool-grid player-count-grid" aria-label="Game participation">
            <div className="pool-tile">
              <span>Players joined</span>
              <strong>{snapshot.totalPlayerCount.toLocaleString()}</strong>
            </div>
            <div className="pool-tile">
              <span>Still in the game</span>
              <strong>{snapshot.activePlayerCount.toLocaleString()}</strong>
            </div>
          </div>
        </section>

        <div className="stack">
          {!snapshot.configured ? (
            <section className="panel">
              <div className="panel__header"><h2>Deployment required</h2></div>
              <p className="panel__body-copy">The interface is ready. Add the deployed game and faucet addresses to enable live contract actions.</p>
            </section>
          ) : null}

          <section className="panel">
            <div className="panel__header">
              <h2>Enter the room</h2>
              <span className="round-label">{snapshot.walletBalance === undefined ? "—" : `${formatEth(snapshot.walletBalance)} ETH`}</span>
            </div>

            {!snapshot.isConnected ? (
              <div className="form-stack">
                <p className="panel__body-copy">
                  {authenticated
                    ? "Your Privy wallet is being prepared on Base Sepolia. This page will unlock as soon as it is ready."
                    : "Sign in with Google, email, phone, or a wallet. Privy creates a Base Sepolia wallet for you automatically."
                  }
                </p>
                <button
                  className="button button--ivory button--wide"
                  type="button"
                  disabled={!privyReady || authenticated}
                  onClick={() => void connectOrCreateWallet()}
                >
                  {!privyReady ? "Loading sign-in…" : authenticated ? "Preparing wallet…" : "Sign in / create wallet"}
                </button>
              </div>
            ) : (
              <div className="form-stack">
                {!snapshot.hasClaimedFaucet ? (
                  <button className="button button--brass button--wide" type="button" disabled={feedback.tone === "pending"} onClick={() => void run("Sending your free starter ETH…", claimFaucet)}>
                    Claim {formatEth(snapshot.faucetClaimAmount)} test ETH — gas free
                  </button>
                ) : (
                  <p className="success-copy">Starter ETH claimed by {shortAddress(snapshot.address)}.</p>
                )}

                {canEnterName ? (
                  <form className="form-stack" onSubmit={submitName}>
                    <label className="round-label" htmlFor="display-name">Display name</label>
                    <input
                      className="text-input"
                      id="display-name"
                      maxLength={16}
                      placeholder="Corner Pocket"
                      value={displayName}
                      onChange={(event) => setDisplayName(event.target.value)}
                    />
                    <button
                      className="button button--ivory button--wide"
                      type="submit"
                      disabled={actions.isPending || (!snapshot.hasClaimedFaucet && !hasWalletFunds)}
                    >
                      Join lobby
                    </button>
                    {!snapshot.hasClaimedFaucet && !hasWalletFunds ? <p className="hint">Claim your starter ETH above, then join with this name.</p> : null}
                  </form>
                ) : null}

                {snapshot.player?.joined && snapshot.playerActive === false ? (
                  <p className="hint">You were eliminated this round. You can still claim any earlier winnings.</p>
                ) : snapshot.player?.joined ? (
                  <p className="success-copy">You’re in as {snapshot.player.displayName}.</p>
                ) : null}
                {snapshot.phase !== Phase.Lobby && !snapshot.player?.joined ? <p className="hint">This game is underway. Join the next one when the current game ends.</p> : null}
              </div>
            )}

            {feedback.message ? <p className={feedback.tone === "error" ? "error-copy" : feedback.tone === "success" ? "success-copy" : "hint"}>{feedback.message}</p> : null}
          </section>

          {snapshot.claimableTotal > 0n ? (
            <section className="panel">
              <div className="panel__header"><h2>Winnings ready</h2><strong>{formatEth(snapshot.claimableTotal)} ETH</strong></div>
              <button className="button button--brass button--wide" type="button" disabled={actions.isPending} onClick={() => void run("Claiming settled rounds…", () => actions.claim(snapshot.claimableRounds))}>
                Claim next batch
              </button>
            </section>
          ) : null}

          <section className="panel">
            <div className="panel__header"><h2>House rules</h2></div>
            <ol className="step-list">
              <li><span>1</span> Place one wager during the 60-second window.</li>
              <li><span>2</span> A losing pick or skipped round eliminates you.</li>
              <li><span>3</span> Refund rounds keep every active player in.</li>
              <li><span>4</span> Winners stay in and split the complete pool.</li>
            </ol>
          </section>
        </div>

        {snapshot.phase === Phase.Betting && snapshot.player?.joined && snapshot.playerActive ? (
          <section className="bet-dock" aria-label="Place a wager">
            {bet && bet.amount > 0n ? (
              <p className="success-copy">Your {formatEth(bet.amount)} ETH wager is locked on {bet.side === Side.Hi ? "Hi" : "Lo"}.</p>
            ) : (
              <>
                <label className="amount-field">
                  <input inputMode="decimal" aria-label="Wager amount in ETH" value={amount} onChange={(event) => setAmount(event.target.value)} />
                  <span>ETH</span>
                </label>
                <div className="choice-grid">
                  <button className="choice-button" type="button" disabled={actions.isPending} onClick={() => placeBet(Side.Hi)}>Hi <small>↑</small></button>
                  <button className="choice-button choice-button--lo" type="button" disabled={actions.isPending} onClick={() => placeBet(Side.Lo)}>Lo <small>↓</small></button>
                </div>
              </>
            )}
          </section>
        ) : null}
      </main>
    </div>
  );
}
