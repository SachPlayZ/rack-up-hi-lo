# Rack Up

Mobile-first, onchain Hi-Lo for Base Sepolia. Players claim starter test ETH without paying gas, join a wallet-gated lobby, and wager on whether the next pool ball will be higher or lower than the current one.

## What is included

- Next.js 16, React 19, TypeScript, wagmi/viem, and Privy authentication.
- Google/email/phone/wallet login with automatic Privy embedded wallets and a dedicated desktop admin desk.
- Foundry contracts for the game, Chainlink VRF v2.5 integration, and the native ETH faucet.
- Onchain lobby with no fixed player cap, 60-second rounds, one bet per wallet, elimination for wrong or skipped bets, pari-mutuel payouts, batched pull claims, force-roll, and timeout refunds.
- Gasless faucet relay authenticated with a five-minute EIP-4361 SIWE challenge.

## Local development

Requirements: Node 22+, npm 10+, and Foundry.

```bash
cp .env.example .env.local
npm install
cd contracts && forge install foundry-rs/forge-std@v1.9.7 OpenZeppelin/openzeppelin-contracts@v5.4.0 Vectorized/solady@v0.1.26 && cd ..
npm run dev
```

The UI renders without deployed contracts, but chain actions stay disabled until `NEXT_PUBLIC_GAME_ADDRESS` and `NEXT_PUBLIC_FAUCET_ADDRESS` are set.

Run checks:

```bash
npm run lint
npm run typecheck
npm test
npm run build
cd contracts && forge test && forge build --sizes
```

## Base Sepolia setup

1. Create a Privy app, enable the login methods you want (Google, email, SMS, and wallet), allowlist the production HTTPS origin, and set `NEXT_PUBLIC_PRIVY_APP_ID`, optional `NEXT_PUBLIC_PRIVY_CLIENT_ID`, and `NEXT_PUBLIC_APP_URL`.
   For the admin wallet, sign in to Privy once before deployment and use that embedded wallet address as `ADMIN_ADDRESS`, or sign in with an existing admin wallet through Privy.
2. Create and fund a Chainlink VRF v2.5 subscription on Base Sepolia with test LINK.
3. Import the deployment wallet into Foundry's encrypted keystore:

   ```bash
   cast wallet import deployer --interactive
   ```

4. Export the non-secret deployment inputs and deploy using the encrypted account:

   ```bash
   export ADMIN_ADDRESS=0x...
   export RELAYER_ADDRESS=0x...
   export VRF_SUBSCRIPTION_ID=...
   cd contracts
   forge script script/DeployBaseSepolia.s.sol:DeployBaseSepolia \
     --rpc-url https://sepolia.base.org \
     --account deployer \
     --sender 0x... \
     --broadcast
   ```

5. Fund the faucet contract and the relayer wallet with Base Sepolia ETH. The faucet defaults to `0.001 ETH` per wallet and can be updated by the owner.
6. Put the deployed addresses in the web environment. Store `FAUCET_AUTH_SECRET` and the testnet-only `FAUCET_RELAYER_PRIVATE_KEY` in the host's encrypted secret manager, never in source control.
7. Verify both contracts on BaseScan and run a live smoke game with the admin wallet and two mobile wallets.

The deployment script uses the official Base Sepolia VRF coordinator and key hash and adds the game as a subscription consumer. The deploying account must own the VRF subscription.

## Game lifecycle

`Lobby → Initial VRF draw → Betting → Roll requested → Settled → Next round`

- The opening ball is uniformly selected from 1–15.
- Later draws are uniformly selected from the other 14 balls, so ties cannot occur.
- Winners divide both pools proportionally. If nobody selected the winning side, all bets become refundable.
- A joined player can force the roll after five minutes. A round can be refunded after a one-hour failed/unrequested oracle timeout.
- Only the owner can start/end games and open the next round; the owner cannot choose a result or withdraw the game pot.
- Players authenticate through Privy. Users without an existing EVM wallet receive an embedded Base Sepolia wallet during login, then claim faucet ETH and choose a display name before joining.

## Security boundaries

- The faucet enforces one claim per address, not one claim per human. Sybil resistance is intentionally out of scope.
- The server relayer can only call the faucet's restricted `claimFor`; keep its balance limited and rotate it if exposed.
- This code targets a testnet. Do not use it with real funds or deploy it to mainnet without an independent audit, multisig ownership, operational monitoring, and legal review.
