import { describe, expect, it } from "vitest";
import { buildClaimBatch } from "./claims";

describe("buildClaimBatch", () => {
  it("skips settled rounds with no claim and totals the rest", () => {
    expect(buildClaimBatch([1n, 2n, 3n], [0n, 12n, 8n])).toEqual({
      roundIds: [2n, 3n],
      total: 20n,
      hasMore: false,
    });
  });

  it("caps a transaction at 20 claims without hiding later rounds", () => {
    const roundIds = Array.from({ length: 21 }, (_, index) => BigInt(index + 1));
    const batch = buildClaimBatch(roundIds, roundIds.map(() => 1n));

    expect(batch.roundIds).toHaveLength(20);
    expect(batch.total).toBe(20n);
    expect(batch.hasMore).toBe(true);
  });
});
