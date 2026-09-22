"use client";

import { useEffect, useState } from "react";
import { SiteHeader } from "@/components/site-header";
import { Countdown } from "@/components/countdown";
import { PoolBall } from "@/components/pool-ball";
import { useGameActions, useGameSnapshot } from "@/hooks/use-game";
import { Phase, phaseLabel } from "@/lib/contracts";
import { errorMessage, formatEth, shortAddress } from "@/lib/format";
import { usePrivyAuth } from "@/hooks/use-privy-auth";

export function AdminConsole() {
  const snapshot = useGameSnapshot();
  const actions = useGameActions(snapshot.refresh);
  const { authenticated, ready: privyReady, connectOrCreateWallet } = usePrivyAuth();
  const [message, setMessage] = useState("");
  const [failed, setFailed] = useState(false);
  const [now, setNow] = useState(0);
  const isOwner = Boolean(snapshot.address && snapshot.owner && snapshot.address.toLowerCase() === snapshot.owner.toLowerCase());
  const round = snapshot.round;
  const bettingClosed = Boolean(now && round && Number(round.bettingClosesAt) <= now);
  const abandonedReady = Boolean(now && round && Number(round.bettingClosesAt) + 3_600 <= now);
  const timeoutReady = Boolean(now && round?.randomnessRequestedAt && Number(round.randomnessRequestedAt) + 3_600 <= now);
  const initialTimeoutReady = Boolean(
    now && snapshot.initialRandomnessRequestedAt && Number(snapshot.initialRandomnessRequestedAt) + 3_600 <= now,
  );

  useEffect(() => {
    const update = () => setNow(Math.floor(Date.now() / 1_000));
    update();
    const timer = window.setInterval(update, 1_000);
    return () => window.clearInterval(timer);
  }, []);

  async function run(label: string, task: () => Promise<unknown>) {
    setFailed(false);
    setMessage(label);
    try {
      await task();
      setMessage("Confirmed on Base Sepolia.");
    } catch (error) {
      setFailed(true);
      setMessage(errorMessage(error));
    }
  }

  if (!snapshot.isConnected) {
    return (
      <div className="app-shell">
        <SiteHeader admin />
        <main className="centered-page">
          <section className="notice-card">
            <p className="eyebrow">Admin desk</p>
            <h1>Connect the table wallet.</h1>
            <p>Only the contract owner can pace rounds and roll the next ball.</p>
            <button
              className="button button--ivory"
              type="button"
              disabled={!privyReady || authenticated}
              onClick={() => void connectOrCreateWallet()}
            >
              {!privyReady ? "Loading sign-in…" : authenticated ? "Preparing wallet…" : "Sign in as admin"}
            </button>
          </section>
        </main>
      </div>
    );
  }

  if (snapshot.configured && !isOwner) {
    return (
      <div className="app-shell">
        <SiteHeader admin />
        <main className="centered-page">
          <section className="notice-card">
            <p className="eyebrow">Read-only desk</p>
            <h1>This wallet is not the room runner.</h1>
            <p>Connected: {shortAddress(snapshot.address)} · Owner: {shortAddress(snapshot.owner)}</p>
          </section>
        </main>
      </div>
    );
  }

  return (
    <div className="app-shell">
      <SiteHeader admin />
      <main className="admin-grid">
        <section className="hero-copy admin-grid__wide">
          <p className="eyebrow">Room runner console</p>
          <h1>Control the pace. Never the outcome.</h1>
          <p>Every draw comes from Chainlink VRF. Your controls only open, close, and advance the table.</p>
        </section>

        <section className="table-card admin-grid__wide">
          <div className="table-card__top">
            <div>
              <div className="round-label">Game {snapshot.currentGameId.toString()} · Round {snapshot.currentRoundId.toString()}</div>
              <div className="status-pill">{phaseLabel[snapshot.phase]}</div>
            </div>
            {snapshot.phase === Phase.Betting && round ? <Countdown deadline={round.bettingClosesAt} /> : null}
          </div>
          <div className="ball-stage">
            <PoolBall number={snapshot.currentBall} rolling={snapshot.phase === Phase.AwaitingInitialBall || snapshot.phase === Phase.AwaitingRoll} />
          </div>
          <div className="pool-grid">
            <div className="pool-tile"><span>Hi pool</span><strong>{formatEth(round?.hiPool)} ETH</strong></div>
            <div className="pool-tile"><span>Lo pool</span><strong>{formatEth(round?.loPool)} ETH</strong></div>
          </div>
        </section>

        <section className="panel">
          <div className="panel__header"><h2>Table controls</h2><span className="round-label">Owner only</span></div>
          <div className="metric-grid">
            <div className="metric"><span>Players</span><strong>{snapshot.players.length}</strong></div>
            <div className="metric"><span>Bettors</span><strong>{round?.bettorCount ?? 0}</strong></div>
            <div className="metric"><span>Faucet reserve</span><strong>{formatEth(snapshot.faucetBalance)}</strong></div>
            <div className="metric"><span>Faucet drop</span><strong>{formatEth(snapshot.faucetClaimAmount)}</strong></div>
          </div>

          <div className="admin-controls">
            {snapshot.phase === Phase.Lobby ? (
              <button className="button button--brass" type="button" disabled={actions.isPending || snapshot.players.length < 2} onClick={() => void run("Requesting the opening ball…", actions.startGame)}>Start game</button>
            ) : null}
            {snapshot.phase === Phase.AwaitingInitialBall && initialTimeoutReady ? (
              <button className="button button--danger" type="button" disabled={actions.isPending} onClick={() => void run("Cancelling the timed-out opening draw…", actions.cancelStaleInitialRequest)}>Return to lobby</button>
            ) : null}
            {snapshot.phase === Phase.Betting ? (
              <>
                <button className="button button--brass" type="button" disabled={actions.isPending || !bettingClosed} onClick={() => void run("Requesting the next ball…", actions.requestRoll)}>Roll ball</button>
                {abandonedReady ? <button className="button button--danger" type="button" disabled={actions.isPending} onClick={() => void run("Refunding the abandoned round…", actions.settleAbandonedRound)}>Refund abandoned</button> : null}
              </>
            ) : null}
            {snapshot.phase === Phase.AwaitingRoll ? (
              <button className="button button--danger" type="button" disabled={actions.isPending || !timeoutReady} onClick={() => void run("Refunding the timed-out round…", actions.settleTimedOutRound)}>Refund timeout</button>
            ) : null}
            {snapshot.phase === Phase.Settled ? (
              <>
                <button className="button button--brass" type="button" disabled={actions.isPending} onClick={() => void run("Opening the next betting window…", actions.openNextRound)}>Next round</button>
                <button className="button button--danger" type="button" disabled={actions.isPending} onClick={() => void run("Ending this game…", actions.endGame)}>End game</button>
              </>
            ) : null}
          </div>
          {message ? <p className={failed ? "error-copy" : "hint"}>{message}</p> : null}
          {snapshot.phase === Phase.Lobby && snapshot.players.length < 2 ? <p className="hint">Two players are required before the opening draw.</p> : null}
        </section>

        <section className="panel">
          <div className="panel__header"><h2>Live roster</h2><span className="round-label">{snapshot.players.length}/100</span></div>
          <div className="lobby-list">
            {snapshot.players.map((player, index) => (
              <div className="lobby-player" key={player.account}>
                <div className="player-ident">
                  <span className="avatar">{player.displayName.charAt(0).toUpperCase()}</span>
                  <div><strong>{player.displayName}</strong><small>{shortAddress(player.account)}</small></div>
                </div>
                <span className="round-label">#{index + 1}</span>
              </div>
            ))}
            {!snapshot.players.length ? <p className="empty-state">Waiting for the first player.</p> : null}
          </div>
        </section>

        <section className="panel">
          <div className="panel__header"><h2>Safety rails</h2></div>
          <ol className="step-list">
            <li><span>1</span> Bets close by onchain timestamp.</li>
            <li><span>2</span> Players may force a roll after five minutes.</li>
            <li><span>3</span> Oracle failures become refunds after one hour.</li>
          </ol>
        </section>
      </main>
    </div>
  );
}
