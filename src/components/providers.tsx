"use client";

import { PrivyProvider } from "@privy-io/react-auth";
import { WagmiProvider as PrivyWagmiProvider } from "@privy-io/wagmi";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { baseSepolia } from "viem/chains";
import { useState } from "react";
import { WagmiProvider as StandardWagmiProvider } from "wagmi";
import { wagmiConfig } from "@/lib/wagmi";
import { AppAuthProvider } from "@/hooks/use-privy-auth";

const privyAppId = process.env.NEXT_PUBLIC_PRIVY_APP_ID || "";
const privyClientId = process.env.NEXT_PUBLIC_PRIVY_CLIENT_ID;

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient());
  const wagmiContent = privyAppId ? (
    <PrivyWagmiProvider config={wagmiConfig}>
      <AppAuthProvider enabled>{children}</AppAuthProvider>
    </PrivyWagmiProvider>
  ) : (
    <StandardWagmiProvider config={wagmiConfig}>
      <AppAuthProvider enabled={false}>{children}</AppAuthProvider>
    </StandardWagmiProvider>
  );
  const content = (
    <QueryClientProvider client={queryClient}>
      {wagmiContent}
    </QueryClientProvider>
  );

  if (!privyAppId) return content;

  return (
    <PrivyProvider
      appId={privyAppId}
      clientId={privyClientId}
      config={{
        loginMethods: ["google", "email", "sms", "wallet"],
        supportedChains: [baseSepolia],
        defaultChain: baseSepolia,
        embeddedWallets: {
          ethereum: { createOnLogin: "users-without-wallets" },
        },
        appearance: {
          theme: "dark",
          accentColor: "#c99b54",
          logo: "/icon.svg",
        },
      }}
    >
      {content}
    </PrivyProvider>
  );
}
