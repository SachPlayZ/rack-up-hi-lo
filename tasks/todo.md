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
- [ ] Link the project with Vercel CLI and deploy it.
- [ ] Verify the remote repository and deployed URL; record any missing runtime setup.

### Verification

- [ ] Confirm GitHub remote and pushed commit.
- [ ] Confirm Vercel deployment status and production URL.

### Review

#### Changed

#### Verified

#### Risks

#### Follow-ups
