import { createHash, createHmac, timingSafeEqual } from "node:crypto";

import { getAddress, type Address } from "viem";
import { createSiweMessage, generateSiweNonce } from "viem/siwe";

export const BASE_SEPOLIA_CHAIN_ID = 84_532;
export const FAUCET_CHALLENGE_COOKIE = "faucet_challenge";
export const FAUCET_CHALLENGE_TTL_SECONDS = 5 * 60;
export const FAUCET_STATEMENT =
  "Sign in to claim Base Sepolia test ETH. This signature does not submit a transaction.";

const TOKEN_VERSION = 1;

export type FaucetChallenge = {
  version: typeof TOKEN_VERSION;
  address: Address;
  nonce: string;
  domain: string;
  uri: string;
  issuedAt: string;
  expirationTime: string;
  expiresAt: number;
  messageHash: string;
};

export class FaucetAuthError extends Error {
  constructor(message = "Invalid or expired faucet challenge") {
    super(message);
    this.name = "FaucetAuthError";
  }
}

export class FaucetConfigurationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "FaucetConfigurationError";
  }
}

export function getFaucetAuthSecret(): string {
  const secret = process.env.FAUCET_AUTH_SECRET?.trim();

  if (!secret || secret.length < 32) {
    throw new FaucetConfigurationError(
      "FAUCET_AUTH_SECRET must contain at least 32 characters",
    );
  }

  return secret;
}

export function createFaucetChallenge(
  address: Address,
  origin: string,
  now = Date.now(),
): { challenge: FaucetChallenge; message: string } {
  const url = new URL(origin);
  const issuedAt = new Date(now).toISOString();
  const expiresAt = now + FAUCET_CHALLENGE_TTL_SECONDS * 1_000;
  const expirationTime = new Date(expiresAt).toISOString();
  const nonce = generateSiweNonce();
  const normalizedAddress = getAddress(address);

  const message = createSiweMessage({
    domain: url.host,
    address: normalizedAddress,
    statement: FAUCET_STATEMENT,
    uri: url.origin,
    version: "1",
    chainId: BASE_SEPOLIA_CHAIN_ID,
    nonce,
    issuedAt: new Date(issuedAt),
    expirationTime: new Date(expirationTime),
  });

  return {
    message,
    challenge: {
      version: TOKEN_VERSION,
      address: normalizedAddress,
      nonce,
      domain: url.host,
      uri: url.origin,
      issuedAt,
      expirationTime,
      expiresAt,
      messageHash: hashMessage(message),
    },
  };
}

export function sealFaucetChallenge(
  challenge: FaucetChallenge,
  secret: string,
): string {
  const payload = Buffer.from(JSON.stringify(challenge)).toString("base64url");
  const signature = sign(payload, secret);

  return `${payload}.${signature}`;
}

export function openFaucetChallenge(
  token: string,
  secret: string,
  now = Date.now(),
): FaucetChallenge {
  if (token.length > 4_096) {
    throw new FaucetAuthError();
  }

  const parts = token.split(".");
  if (parts.length !== 2) {
    throw new FaucetAuthError();
  }

  const [payload, providedSignature] = parts;
  const expectedSignature = sign(payload, secret);

  if (!safeEqual(providedSignature, expectedSignature)) {
    throw new FaucetAuthError();
  }

  let value: unknown;
  try {
    value = JSON.parse(Buffer.from(payload, "base64url").toString("utf8"));
  } catch {
    throw new FaucetAuthError();
  }

  if (!isFaucetChallenge(value) || value.expiresAt <= now) {
    throw new FaucetAuthError();
  }

  return value;
}

export function validateFaucetChallengeMessage({
  challenge,
  message,
  now = Date.now(),
}: {
  challenge: FaucetChallenge;
  message: string;
  now?: number;
}): Address {
  if (
    challenge.expiresAt <= now ||
    hashMessage(message) !== challenge.messageHash
  ) {
    throw new FaucetAuthError();
  }

  return challenge.address;
}

function hashMessage(message: string): string {
  return createHash("sha256").update(message).digest("base64url");
}

function sign(payload: string, secret: string): string {
  return createHmac("sha256", secret).update(payload).digest("base64url");
}

function safeEqual(left: string, right: string): boolean {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);

  return (
    leftBuffer.length === rightBuffer.length &&
    timingSafeEqual(leftBuffer, rightBuffer)
  );
}

function isFaucetChallenge(value: unknown): value is FaucetChallenge {
  if (!value || typeof value !== "object") {
    return false;
  }

  const candidate = value as Record<string, unknown>;
  return (
    candidate.version === TOKEN_VERSION &&
    typeof candidate.address === "string" &&
    /^0x[0-9a-fA-F]{40}$/.test(candidate.address) &&
    typeof candidate.nonce === "string" &&
    /^[a-zA-Z0-9]{8,}$/.test(candidate.nonce) &&
    typeof candidate.domain === "string" &&
    candidate.domain.length > 0 &&
    typeof candidate.uri === "string" &&
    typeof candidate.issuedAt === "string" &&
    typeof candidate.expirationTime === "string" &&
    typeof candidate.expiresAt === "number" &&
    Number.isSafeInteger(candidate.expiresAt) &&
    typeof candidate.messageHash === "string" &&
    candidate.messageHash.length > 0
  );
}
