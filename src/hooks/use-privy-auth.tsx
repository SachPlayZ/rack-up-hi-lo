"use client";

import { useConnectOrCreateWallet, usePrivy } from "@privy-io/react-auth";
import { createContext, useContext } from "react";

type AppAuth = {
  authenticated: boolean;
  ready: boolean;
  connectOrCreateWallet: () => void;
};

const fallbackAuth: AppAuth = {
  authenticated: false,
  ready: true,
  connectOrCreateWallet: () => undefined,
};

const AuthContext = createContext<AppAuth>(fallbackAuth);

function PrivyAuthBridge({ children }: { children: React.ReactNode }) {
  const { authenticated, ready } = usePrivy();
  const { connectOrCreateWallet } = useConnectOrCreateWallet();

  return (
    <AuthContext.Provider value={{ authenticated, ready, connectOrCreateWallet }}>
      {children}
    </AuthContext.Provider>
  );
}

export function AppAuthProvider({ enabled, children }: { enabled: boolean; children: React.ReactNode }) {
  if (!enabled) {
    return <AuthContext.Provider value={fallbackAuth}>{children}</AuthContext.Provider>;
  }

  return <PrivyAuthBridge>{children}</PrivyAuthBridge>;
}

export function usePrivyAuth() {
  return useContext(AuthContext);
}
