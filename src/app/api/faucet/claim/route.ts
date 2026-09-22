import { NextRequest, NextResponse } from "next/server";
import { isHex, type Hex } from "viem";

import {
  FAUCET_CHALLENGE_COOKIE,
  FaucetAuthError,
  FaucetConfigurationError,
  getFaucetAuthSecret,
  openFaucetChallenge,
  validateFaucetChallengeMessage,
} from "@/lib/server/faucet-auth";
import {
  hasClaimed,
  relayFaucetClaim,
  verifyFaucetSignature,
} from "@/lib/server/faucet-relayer";

export const runtime = "nodejs";

export async function POST(request: NextRequest) {
  const challengeToken = request.cookies.get(FAUCET_CHALLENGE_COOKIE)?.value;

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return clearChallenge(
      NextResponse.json({ error: "Invalid JSON body" }, { status: 400 }),
    );
  }

  const claim = readClaim(body);
  if (!claim) {
    return clearChallenge(
      NextResponse.json(
        { error: "A SIWE message and signature are required" },
        { status: 400 },
      ),
    );
  }

  if (!challengeToken) {
    return clearChallenge(
      NextResponse.json(
        { error: "Faucet challenge is missing or expired" },
        { status: 401 },
      ),
    );
  }

  try {
    const challenge = openFaucetChallenge(
      challengeToken,
      getFaucetAuthSecret(),
    );
    const address = validateFaucetChallengeMessage({
      challenge,
      message: claim.message,
    });
    const signatureIsValid = await verifyFaucetSignature({
      address,
      domain: challenge.domain,
      message: claim.message,
      nonce: challenge.nonce,
      signature: claim.signature,
    });
    if (!signatureIsValid) {
      throw new FaucetAuthError();
    }

    if (await hasClaimed(address)) {
      return clearChallenge(
        NextResponse.json(
          { error: "This wallet has already claimed from the faucet" },
          { status: 409 },
        ),
      );
    }

    const transactionHash = await relayFaucetClaim(address);
    return clearChallenge(
      NextResponse.json(
        { address, transactionHash },
        { headers: { "Cache-Control": "no-store" } },
      ),
    );
  } catch (error) {
    if (error instanceof FaucetAuthError) {
      return clearChallenge(
        NextResponse.json(
          { error: "Faucet signature is invalid or expired" },
          { status: 401 },
        ),
      );
    }

    if (error instanceof FaucetConfigurationError) {
      console.error(error.message);
      return clearChallenge(
        NextResponse.json(
          { error: "Faucet relayer is not configured" },
          { status: 503 },
        ),
      );
    }

    console.error("Faucet claim failed", error);

    // A competing request can win between the preflight read and transaction.
    try {
      const challenge = openFaucetChallenge(
        challengeToken,
        getFaucetAuthSecret(),
      );
      if (await hasClaimed(challenge.address)) {
        return clearChallenge(
          NextResponse.json(
            { error: "This wallet has already claimed from the faucet" },
            { status: 409 },
          ),
        );
      }
    } catch {
      // Preserve the generic upstream error below.
    }

    return clearChallenge(
      NextResponse.json(
        { error: "Faucet transaction failed" },
        { status: 502 },
      ),
    );
  }
}

function readClaim(
  body: unknown,
): { message: string; signature: Hex } | undefined {
  if (!body || typeof body !== "object") {
    return undefined;
  }

  const { message, signature } = body as Record<string, unknown>;
  if (
    typeof message !== "string" ||
    message.length === 0 ||
    message.length > 4_096 ||
    typeof signature !== "string" ||
    !isHex(signature)
  ) {
    return undefined;
  }

  return { message, signature };
}

function clearChallenge(response: NextResponse): NextResponse {
  response.cookies.set({
    name: FAUCET_CHALLENGE_COOKIE,
    value: "",
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "strict",
    path: "/api/faucet",
    maxAge: 0,
    expires: new Date(0),
  });
  return response;
}
