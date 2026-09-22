"use client";

import Link from "next/link";
import { useAccount, useChainId, useSwitchChain } from "wagmi";
import { baseSepolia } from "wagmi/chains";
import { shortAddress } from "@/lib/format";
import { usePrivyAuth } from "@/hooks/use-privy-auth";

export function SiteHeader({ admin = false }: { admin?: boolean }) {
  const { authenticated, ready, connectOrCreateWallet } = usePrivyAuth();
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const { switchChain, isPending: isSwitching } = useSwitchChain();
  const signedIn = authenticated || isConnected;
  const wrongNetwork = signedIn && isConnected && chainId !== baseSepolia.id;
  const buttonLabel = !ready
    ? "Loading…"
    : wrongNetwork
      ? "Switch network"
      : isConnected
        ? shortAddress(address)
        : authenticated
          ? "Preparing wallet…"
          : "Sign in / create wallet";

  return (
    <header className="site-header">
      <Link className="brand" href="/" aria-label="Rack Up home">
        <span className="brand__mark">8</span>
        <span>Rack Up</span>
      </Link>
      <div className="header-actions">
        <span className="network-pill">Base Sepolia</span>
        <Link className="button button--ghost button--compact desktop-only" href={admin ? "/" : "/admin"}>
          {admin ? "Player view" : "Admin desk"}
        </Link>
        {wrongNetwork ? (
          <button
            className="button button--brass button--compact"
            type="button"
            disabled={isSwitching}
            onClick={() => switchChain({ chainId: baseSepolia.id })}
          >
            {isSwitching ? "Switching…" : "Switch network"}
          </button>
        ) : (
          <button
            className="button button--ivory button--compact"
            type="button"
            disabled={!ready || (authenticated && !isConnected)}
            onClick={() => void connectOrCreateWallet()}
          >
            {buttonLabel}
          </button>
        )}
      </div>
    </header>
  );
}
