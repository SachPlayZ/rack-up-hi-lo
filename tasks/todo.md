# Todo

## Plan

- [x] Scaffold Next.js 16 TypeScript app and Foundry contract workspace.
- [x] Implement `HiLoGame` VRF state machine, pari-mutuel payouts, liveness refunds, and lobby.
- [x] Implement native ETH faucet, deployment scripts, and contract tests.
- [x] Implement wallet providers, contract reads/writes, gasless faucet API, and shared game state.
- [x] Build mobile player experience and desktop admin console in the pool-hall visual system.
- [x] Add documentation, environment templates, CI, and deployment configuration.

## Verification

- [x] Run Foundry tests, fuzz/invariant tests, build-size check, and static analysis where available.
- [x] Run frontend lint, typecheck, component tests, and production build.
- [x] Run responsive browser smoke checks and inspect final repository diff/status.

## Review

### Changed

- Added Base Sepolia Hi-Lo and one-claim faucet contracts, VRF integration, deployment script, and 43 Foundry tests.
- Added the Privy/wagmi player table, owner-gated admin desk, SIWE faucet relay, polling/event resync, and responsive pool-hall UI.
- Replaced Reown wallet connection with Privy Google/email/SMS/wallet login, automatic embedded Base Sepolia wallets, and a name-first faucet-gated lobby flow.
- Added environment templates, CI, component/API tests, Playwright flows, and deployment/runbook documentation.

### Verified

- `forge fmt --check`, 43 Foundry unit/fuzz/invariant tests, size checks, and medium/high `forge lint` checks pass.
- ESLint, TypeScript, 15 Vitest tests, production build, and dependency audit pass.
- Four Playwright mobile/desktop flows pass; manual 390px player/admin browser inspection has no horizontal overflow.
- Privy SDK integration compiles, and `npm ci --dry-run` resolves the committed lockfile cleanly.

### Risks

- Testnet only; contracts require independent audit before any real-value deployment.
- Slither/Aderyn are not installed; Foundry lint and invariant coverage were used locally.
- Privy social-login and embedded-wallet behavior still requires real iOS Safari and Android Chrome device testing with a valid Privy app ID.

### Follow-ups

- Provide funded admin/relayer keystores, Chainlink subscription, Privy app ID, and hosting secrets to deploy and run the live two-wallet smoke game.

## GitHub and Vercel publish

### Plan

- [x] Verify auth/configuration and repository contents before publishing.
- [x] Create a private GitHub repository, commit the app, and push `main`.
- [x] Link the project with Vercel CLI and deploy it.
- [x] Verify the remote repository and deployed URL; record any missing runtime setup.

### Verification

- [x] Confirm GitHub remote and pushed commit.
- [x] Confirm Vercel deployment status and production URL.

### Review

#### Changed

- Created private GitHub repository `SachPlayZ/rack-up-hi-lo`; pushed `main` through commit `3cf0b41`.
- Linked Vercel project `rack-up-hi-lo`, set its framework to Next.js, and deployed production.

#### Verified

- `gh repo view` confirms a private repository on `main`; local `main` tracks `origin/main` and is clean.
- Vercel reports production deployment `READY`; `https://rack-up-hi-lo.vercel.app` returns HTTP 200.

#### Risks

- Privy origin allowlist status is unconfirmed; live sign-in and gameplay smoke tests remain.

#### Follow-ups

- Confirm the Privy origin allowlist and run the live player/faucet/game smoke tests.

## Base Sepolia deployment

### Plan

- [x] Record the admin address and check Base Sepolia balance and VRF subscription state.
- [x] Confirm the `chainlink` keystore is the VRF subscription owner and can manage it.
- [x] Fund the VRF subscription with test LINK.
- [ ] Allowlist the production Privy origin.
- [x] Deploy the game and faucet with the encrypted Foundry keystore; verify owner and VRF consumer.
- [x] Configure Vercel contract/faucet settings and redeploy production.
- [x] Fund the faucet and relayer.
- [ ] Transfer `HiLoGame` ownership to the requested room runner and verify the two-step acceptance.
- [ ] Run a live lobby/faucet smoke test.

### Verification

- [x] Confirm Base Sepolia chain ID, admin wallet balance, and VRF subscription owner/funding.
- [x] Verify deployed contract addresses, ownership, and VRF consumer registration.
- [x] Verify Vercel production environment and deployment readiness.
- [x] Verify the live faucet challenge endpoint returns HTTP 200 and the sign-in control initializes.
- [ ] Verify the requested runner is the `HiLoGame` owner and can authenticate through Privy.
- [ ] Run a live lobby/faucet smoke test after funding and Privy origin setup.

### Review

#### Changed

- Set the production Privy App ID and production app URL in Vercel; redeployed successfully.
- Deployed `HiLoGame` at `0x2555423E6c7098C8B59baa6E797B2Be23732638B` and faucet at `0x01357B8242afb2209c0B4Fd8Da6671e4a69D21Ec`.
- Stored a dedicated faucet relayer private key and random auth secret as Vercel production secrets; relayer address is `0x0C33957841579B28E6C32Ca452a8EE2322E69f23`.
- Added contract/RPC configuration to Vercel and redeployed production.

#### Verified

- Admin wallet has 20 Base Sepolia ETH.
- VRF subscription holds 20 LINK; its owner is `0xAc99290B7Cd053276839Fb4bfB33dA9cdABF727D`.
- Both deployed contracts currently report the original admin as owner, and the subscription lists the game as consumer.
- Production Vercel deployment is `READY`; the production URL returns HTTP 200.
- Faucet holds 0.5 ETH, relayer holds 0.2 ETH, VRF subscription holds 20 LINK, and the live faucet challenge endpoint returns HTTP 200.

#### Risks

- Privy login needs the production origin allowlisted if that has not already been done.
- A real sign-in, faucet claim, and complete two-player game smoke test still need to be performed.
- Runner transfer requires the current owner's transaction and the new runner's `acceptOwnership()` transaction; keep both keystore passwords local.

#### Follow-ups

- Confirm the Privy origin is allowlisted at `https://rack-up-hi-lo.vercel.app`; then perform real player sign-in/faucet and game smoke tests.
- Transfer game ownership to `0xAc99290B7Cd053276839Fb4bfB33dA9cdABF727D`; keep faucet ownership unchanged unless separately requested.
