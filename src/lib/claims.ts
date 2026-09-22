export function buildClaimBatch(
  roundIds: bigint[],
  amounts: bigint[],
  limit = 20,
) {
  const eligible = roundIds
    .map((roundId, index) => ({ roundId, amount: amounts[index] ?? 0n }))
    .filter(({ amount }) => amount > 0n);
  const batch = eligible.slice(0, limit);

  return {
    roundIds: batch.map(({ roundId }) => roundId),
    total: batch.reduce((sum, { amount }) => sum + amount, 0n),
    hasMore: eligible.length > batch.length,
  };
}
