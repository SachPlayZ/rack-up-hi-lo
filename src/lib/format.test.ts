import { describe, expect, it } from "vitest";
import { errorMessage, formatEth, secondsRemaining, shortAddress } from "./format";

describe("format helpers", () => {
  it("shortens a wallet address", () => {
    expect(shortAddress("0x1234567890abcdef1234567890abcdef12345678")).toBe("0x1234…5678");
  });

  it("formats ether values", () => {
    expect(formatEth(1_250_000_000_000_000n)).toBe("0.0013");
  });

  it("clamps an expired countdown", () => {
    expect(secondsRemaining(100, 101_000)).toBe(0);
    expect(secondsRemaining(103, 100_001)).toBe(3);
  });

  it("turns wallet failures into useful transaction status", () => {
    expect(errorMessage(new Error("User rejected the request"))).toBe("Wallet request cancelled.");
    expect(errorMessage(new Error("insufficient funds for gas"))).toBe(
      "Not enough Base Sepolia ETH for this action.",
    );
  });
});
