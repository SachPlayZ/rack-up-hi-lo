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

- Production URL is now confirmed allowlisted in Privy; live sign-in and gameplay smoke tests remain.

#### Follow-ups

- Run the live player/faucet/game smoke tests.

## Base Sepolia deployment

### Plan

- [x] Record the admin address and check Base Sepolia balance and VRF subscription state.
- [x] Confirm the `chainlink` keystore is the VRF subscription owner and can manage it.
- [x] Fund the VRF subscription with test LINK.
- [x] Allowlist the production Privy origin (confirmed by user).
- [x] Deploy the game and faucet with the encrypted Foundry keystore; verify owner and VRF consumer.
- [x] Configure Vercel contract/faucet settings and redeploy production.
- [x] Fund the original faucet and relayer.
- [x] Fresh-deploy game and faucet with `0xAc99290B7Cd053276839Fb4bfB33dA9cdABF727D` as owner.
- [x] Point Vercel at the fresh contracts and redeploy production.
- [x] Fund the fresh faucet and confirm relayer funding.
- [ ] Retire old contracts: transfer ownership, move the old faucet reserve, and remove the old VRF consumer.
- [ ] Run a live lobby/faucet smoke test.

### Verification

- [x] Confirm Base Sepolia chain ID, admin wallet balance, and VRF subscription owner/funding.
- [x] Verify deployed contract addresses, ownership, and VRF consumer registration.
- [x] Verify Vercel production environment and deployment readiness.
- [x] Verify the live faucet challenge endpoint returns HTTP 200 and the sign-in control initializes.
- [x] Verify fresh game/faucet owners, relayer, VRF consumer, and production configuration.
- [x] Verify fresh faucet balance, production site, and faucet challenge endpoint; user confirmed Privy allowlist.
- [ ] Verify old ownership/funds/VRF consumer are retired without moving the `0xe34...` EOA balance.
- [ ] Run a live lobby/faucet smoke test.

### Review

#### Changed

- Set the production Privy App ID and production app URL in Vercel; redeployed successfully.
- Deployed `HiLoGame` at `0x2555423E6c7098C8B59baa6E797B2Be23732638B` and faucet at `0x01357B8242afb2209c0B4Fd8Da6671e4a69D21Ec`.
- Stored a dedicated faucet relayer private key and random auth secret as Vercel production secrets; relayer address is `0x0C33957841579B28E6C32Ca452a8EE2322E69f23`.
- Added contract/RPC configuration to Vercel and redeployed production.
- Fresh-deployed `HiLoGame` at `0x3cd22D98571884dC9d0692e520B5A7Aa4d95B22A` and faucet at `0xC217F6b9bF6d249B328D7c3F8794582457658c5c`, both owned by `0xAc99290B7Cd053276839Fb4bfB33dA9cdABF727D`.
- Updated Vercel to the fresh contract addresses and redeployed production.

#### Verified

- Admin wallet has 20 Base Sepolia ETH.
- VRF subscription holds 20 LINK; its owner is `0xAc99290B7Cd053276839Fb4bfB33dA9cdABF727D`.
- The old contract pair still has the original admin as owner; the old faucet holds 0.5 ETH.
- Fresh game and faucet ownership is `0xAc99290B7Cd053276839Fb4bfB33dA9cdABF727D`; the subscription contains both old and new game consumers.
- New faucet points to the existing relayer; fresh faucet holds 0.7 ETH (700 starter claims at 0.001 ETH each), relayer holds 0.2 ETH.
- Production URL is allowlisted in Privy (user-confirmed); production site and faucet challenge endpoint return HTTP 200.
- Production Vercel deployment is `READY`; the production URL returns HTTP 200.
- Faucet holds 0.5 ETH, relayer holds 0.2 ETH, VRF subscription holds 20 LINK, and the live faucet challenge endpoint returns HTTP 200.

#### Risks

- A real sign-in, faucet claim, and complete two-player game smoke test still need to be performed.
- Fresh faucet deployment resets its permanent one-claim registry; previously claimed wallets can claim once again.
- Old contract cleanup requires local signatures from the current owner and subscription owner; keep keystore passwords local.

#### Follow-ups

- Retire the old contracts and move their 0.5 ETH reserve as previously agreed; this does not block testing the fresh deployment.
- Perform real player sign-in/faucet and two-player game smoke tests.

## Live elimination and roster changes

### Plan

- [x] Replace the 100-player cap with scalable counts and paginated roster reads.
- [x] Keep correct bettors in the game; eliminate wrong bettors and skippers on decisive rounds; preserve everyone through refund rounds.
- [x] Increase betting windows from 30 to 60 seconds.
- [x] Replace player/admin live rosters with joined/active counts; show remaining display names after admin ends a game.
- [x] Update contract/frontend tests and game documentation.

### Verification

- [x] Run Foundry unit, fuzz, invariant, build-size, and lint checks.
- [x] Run frontend lint, typecheck, tests, and production build.
- [x] Inspect responsive player/admin screens and final diff.

### Review

#### Changed

- Removed the fixed 100-player cap; added joined/active counts and 100-entry paginated roster views.
- Added winner-stays elimination on decisive rounds; losing bets and skippers are out, refunds preserve players, and prior claims remain independent.
- Set betting duration to 60 seconds.
- Removed player rail and live admin roster; added counts and an end-game survivor-name list.

#### Verified

- 48 Foundry tests, including 105 additional lobby joins, pagination, elimination, refunds, empty-round handling, and active-count invariant.
- Foundry format/build-size/high-severity lint; frontend lint, typecheck, 15 unit tests, production build, and 4 mobile/desktop Playwright checks pass.
- Screenshot-checked mobile player counts and desktop admin gate; no horizontal overflow. Final diff passes `git diff --check`.

#### Risks

- `HiLoGame` is non-upgradeable; the updated rules are live at the new production contract address.
- The older games remain deployed and registered as VRF consumers.
- There is no fixed lobby cap; roster reads are paginated in batches of 100 to avoid unbounded RPC calls.

#### Follow-ups

- Retire the old game and run a live mobile/two-player/VRF smoke game.
- Run a live mobile/two-player/VRF smoke game after deployment.

#### Unresolved questions

- None. User confirmed skipped decisive rounds should eliminate players.

## Publish live elimination game

### Plan

- [x] Add a game-only Base Sepolia deployment script; keep the funded faucet unchanged.
- [x] Deploy with the encrypted `chainlink` keystore and register the new game with the funded VRF subscription.
- [x] Verify owner, VRF consumer, subscription funding, and deployed bytecode.
- [x] Update only the production game address.
- [x] Publish the code to GitHub and deploy on Vercel CLI.
- [x] Verify production serves the new app and still uses the funded faucet.

### Verification

- [x] Run Foundry format/test checks after adding the deploy script.
- [x] Verify onchain contract state and production game address; confirm funded faucet remains intact.
- [x] Inspect final Git diff and publish status.

### Review

#### Changed

- Added a game-only deployment script and deployed `HiLoGame` at `0x93bE1040670dAe5Fc89323fA611ee3CFC16aA169`; existing faucet was preserved.
- Updated Vercel production game address, pushed commit `313e38a`, and deployed with Vercel CLI (`dpl_CfBiXMvQmW6SFULcTdQM3Nygz7JP`).

#### Verified

- 48 Foundry tests and format/build checks pass; frontend lint, typecheck, 15 tests, and production build pass.
- New game owner is `0xAc99290B7Cd053276839Fb4bfB33dA9cdABF727D`; it is registered on Base Sepolia chain `84532` with the funded subscription (about 20 LINK). Runtime bytecode is present.
- Subscription consumer list includes the new game; existing faucet remains `0xC217F6b9bF6d249B328D7c3F8794582457658c5c` with `0.698 ETH` at verification.
- Production Vercel config matches the new game and existing faucet; homepage and faucet challenge return HTTP 200; deployed app bundle contains the new game address.
- GitHub `main` contains commit `313e38a`; Vercel deployment is `READY` and aliased to `https://rack-up-hi-lo.vercel.app`.

#### Risks

- The old game remains deployed and registered as a VRF consumer; this deployment does not retire or alter it.
- A full live two-player oracle round still requires player wallets and separate gameplay transactions.

#### Follow-ups

- Retire the old contracts and run a live two-player smoke game.
