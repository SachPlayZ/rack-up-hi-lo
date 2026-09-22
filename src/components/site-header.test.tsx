import { fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { baseSepolia } from "wagmi/chains";
import { SiteHeader } from "./site-header";

const connectOrCreateWallet = vi.fn();
const switchChain = vi.fn();
let account = { address: undefined as `0x${string}` | undefined, isConnected: false };
let chainId: number = baseSepolia.id;
let privy = { authenticated: false, ready: true };

vi.mock("@/hooks/use-privy-auth", () => ({ usePrivyAuth: () => ({ ...privy, connectOrCreateWallet }) }));
vi.mock("wagmi", () => ({
  useAccount: () => account,
  useChainId: () => chainId,
  useSwitchChain: () => ({ switchChain, isPending: false }),
}));

describe("SiteHeader", () => {
  beforeEach(() => {
    connectOrCreateWallet.mockReset();
    switchChain.mockReset();
    account = { address: undefined, isConnected: false };
    chainId = baseSepolia.id;
    privy = { authenticated: false, ready: true };
  });

  it("opens Privy sign-in with embedded wallet creation", () => {
    render(<SiteHeader />);
    fireEvent.click(screen.getByRole("button", { name: "Sign in / create wallet" }));
    expect(connectOrCreateWallet).toHaveBeenCalledOnce();
  });

  it("prompts a connected wallet to switch to Base Sepolia", () => {
    account = { address: "0x1234567890abcdef1234567890abcdef12345678", isConnected: true };
    chainId = 1;
    render(<SiteHeader />);
    fireEvent.click(screen.getByRole("button", { name: "Switch network" }));
    expect(switchChain).toHaveBeenCalledWith({ chainId: baseSepolia.id });
  });
});
