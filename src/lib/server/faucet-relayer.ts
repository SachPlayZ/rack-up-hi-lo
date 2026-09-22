import { privateKeyToAccount } from "viem/accounts";
import {
  createPublicClient,
  createWalletClient,
  getAddress,
  http,
  type Address,
  type Hex,
} from "viem";
import { baseSepolia } from "viem/chains";

import { FaucetConfigurationError } from "@/lib/server/faucet-auth";

const faucetAbi = [
  {
    type: "function",
    name: "hasClaimed",
    stateMutability: "view",
    inputs: [{ name: "recipient", type: "address" }],
    outputs: [{ name: "", type: "bool" }],
  },
  {
    type: "function",
    name: "claimFor",
    stateMutability: "nonpayable",
    inputs: [{ name: "recipient", type: "address" }],
    outputs: [],
  },
] as const;

let cachedRelayer: ReturnType<typeof createFaucetRelayer> | undefined;

export function getFaucetRelayer(): ReturnType<typeof createFaucetRelayer> {
  if (cachedRelayer) {
    return cachedRelayer;
  }

  cachedRelayer = createFaucetRelayer();
  return cachedRelayer;
}

function createFaucetRelayer() {
  const rpcUrl = requiredEnv("BASE_SEPOLIA_RPC_URL");
  const faucetAddress = readAddress(
    "NEXT_PUBLIC_FAUCET_ADDRESS",
    requiredEnv("NEXT_PUBLIC_FAUCET_ADDRESS"),
  );
  const privateKey = readPrivateKey(requiredEnv("FAUCET_RELAYER_PRIVATE_KEY"));
  const transport = http(rpcUrl, { retryCount: 2, timeout: 15_000 });

  return {
    faucetAddress,
    publicClient: createPublicClient({ chain: baseSepolia, transport }),
    walletClient: createWalletClient({
      account: privateKeyToAccount(privateKey),
      chain: baseSepolia,
      transport,
    }),
  };
}

export async function hasClaimed(address: Address): Promise<boolean> {
  const { faucetAddress, publicClient } = getFaucetRelayer();

  return publicClient.readContract({
    address: faucetAddress,
    abi: faucetAbi,
    functionName: "hasClaimed",
    args: [address],
  });
}

export async function verifyFaucetSignature({
  address,
  domain,
  message,
  nonce,
  signature,
}: {
  address: Address;
  domain: string;
  message: string;
  nonce: string;
  signature: Hex;
}): Promise<boolean> {
  const { publicClient } = getFaucetRelayer();

  return publicClient.verifySiweMessage({
    address,
    domain,
    message,
    nonce,
    signature,
    time: new Date(),
  });
}

export async function relayFaucetClaim(address: Address): Promise<Hex> {
  const { faucetAddress, publicClient, walletClient } = getFaucetRelayer();
  const hash = await walletClient.writeContract({
    address: faucetAddress,
    abi: faucetAbi,
    functionName: "claimFor",
    args: [address],
  });
  const receipt = await publicClient.waitForTransactionReceipt({ hash });

  if (receipt.status !== "success") {
    throw new Error("Faucet claim transaction reverted");
  }

  return hash;
}

function requiredEnv(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new FaucetConfigurationError(`${name} is not configured`);
  }
  return value;
}

function readAddress(name: string, value: string): Address {
  try {
    return getAddress(value);
  } catch {
    throw new FaucetConfigurationError(`${name} is not a valid address`);
  }
}

function readPrivateKey(value: string): Hex {
  const normalized = value.startsWith("0x") ? value : `0x${value}`;
  if (!/^0x[0-9a-fA-F]{64}$/.test(normalized)) {
    throw new FaucetConfigurationError(
      "FAUCET_RELAYER_PRIVATE_KEY is not a valid private key",
    );
  }
  return normalized as Hex;
}
