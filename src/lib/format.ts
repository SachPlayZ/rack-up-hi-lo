import { formatEther } from "viem";

export function shortAddress(address?: string) {
  if (!address) return "Not connected";
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}

export function formatEth(value?: bigint, maximumFractionDigits = 4) {
  if (value === undefined) return "—";
  const numeric = Number(formatEther(value));
  return new Intl.NumberFormat("en-US", { maximumFractionDigits }).format(numeric);
}

export function secondsRemaining(deadline: bigint | number, nowMs: number) {
  const deadlineMs = Number(deadline) * 1_000;
  return Math.max(0, Math.ceil((deadlineMs - nowMs) / 1_000));
}

export function errorMessage(error: unknown) {
  if (!(error instanceof Error)) return "Something went wrong.";
  const message = error.message.split("\n")[0];
  if (message.includes("User rejected") || message.includes("User denied")) return "Wallet request cancelled.";
  if (message.includes("insufficient funds")) return "Not enough Base Sepolia ETH for this action.";
  return message.length > 140 ? `${message.slice(0, 137)}…` : message;
}

