import { describe, expect, it } from "vitest";

import {
  createFaucetChallenge,
  FaucetAuthError,
  FAUCET_CHALLENGE_TTL_SECONDS,
  openFaucetChallenge,
  sealFaucetChallenge,
  validateFaucetChallengeMessage,
} from "@/lib/server/faucet-auth";

const ADDRESS = "0x0000000000000000000000000000000000000001";
const SECRET = "test-secret-that-is-at-least-32-characters-long";
const NOW = Date.parse("2026-09-22T12:00:00.000Z");

describe("faucet challenge tokens", () => {
  it("round trips an authentic unexpired challenge", () => {
    const { challenge } = createFaucetChallenge(
      ADDRESS,
      "https://hilo.example",
      NOW,
    );
    const token = sealFaucetChallenge(challenge, SECRET);

    expect(openFaucetChallenge(token, SECRET, NOW)).toEqual(challenge);
    expect(challenge.domain).toBe("hilo.example");
    expect(challenge.expiresAt).toBe(
      NOW + FAUCET_CHALLENGE_TTL_SECONDS * 1_000,
    );
  });

  it("rejects a modified token", () => {
    const { challenge } = createFaucetChallenge(
      ADDRESS,
      "https://hilo.example",
      NOW,
    );
    const token = sealFaucetChallenge(challenge, SECRET);
    const [payload, signature] = token.split(".");
    const tampered = `${payload.slice(0, -1)}A.${signature}`;

    expect(() => openFaucetChallenge(tampered, SECRET, NOW)).toThrow(
      FaucetAuthError,
    );
  });

  it("rejects a challenge at its expiration boundary", () => {
    const { challenge } = createFaucetChallenge(
      ADDRESS,
      "https://hilo.example",
      NOW,
    );
    const token = sealFaucetChallenge(challenge, SECRET);

    expect(() =>
      openFaucetChallenge(token, SECRET, challenge.expiresAt),
    ).toThrow(FaucetAuthError);
  });

  it("binds the cookie to the exact server-issued message", () => {
    const { challenge, message } = createFaucetChallenge(
      ADDRESS,
      "https://hilo.example",
      NOW,
    );

    expect(
      validateFaucetChallengeMessage({ challenge, message, now: NOW }),
    ).toBe(ADDRESS);
    expect(() =>
      validateFaucetChallengeMessage({
        challenge,
        message: `${message}\nResources:\n- https://attacker.example`,
        now: NOW,
      }),
    ).toThrow(FaucetAuthError);
  });
});
