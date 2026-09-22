import { NextRequest, NextResponse } from "next/server";
import { getAddress, isAddress } from "viem";

import {
  createFaucetChallenge,
  FAUCET_CHALLENGE_COOKIE,
  FAUCET_CHALLENGE_TTL_SECONDS,
  FaucetConfigurationError,
  getFaucetAuthSecret,
  sealFaucetChallenge,
} from "@/lib/server/faucet-auth";

export const runtime = "nodejs";

export async function POST(request: NextRequest) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const address = readAddress(body);
  if (!address) {
    return NextResponse.json(
      { error: "A valid wallet address is required" },
      { status: 400 },
    );
  }

  try {
    const authSecret = getFaucetAuthSecret();
    const { challenge, message } = createFaucetChallenge(
      getAddress(address),
      request.nextUrl.origin,
    );
    const response = NextResponse.json(
      { message, expiresAt: challenge.expirationTime },
      { headers: { "Cache-Control": "no-store" } },
    );

    response.cookies.set({
      name: FAUCET_CHALLENGE_COOKIE,
      value: sealFaucetChallenge(challenge, authSecret),
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "strict",
      path: "/api/faucet",
      maxAge: FAUCET_CHALLENGE_TTL_SECONDS,
      expires: new Date(challenge.expiresAt),
    });

    return response;
  } catch (error) {
    if (error instanceof FaucetConfigurationError) {
      console.error(error.message);
      return NextResponse.json(
        { error: "Faucet authentication is not configured" },
        { status: 503 },
      );
    }

    console.error("Failed to create faucet challenge", error);
    return NextResponse.json(
      { error: "Unable to create faucet challenge" },
      { status: 500 },
    );
  }
}

function readAddress(body: unknown): string | undefined {
  if (!body || typeof body !== "object") {
    return undefined;
  }

  const address = (body as Record<string, unknown>).address;
  return typeof address === "string" && isAddress(address)
    ? address
    : undefined;
}
