# Hi-Lo contracts

Foundry workspace for the Base Sepolia Hi-Lo game and one-time native ETH faucet.

## Contracts

- `HiLoGame`: 100-player onchain lobby, 30-second pari-mutuel rounds, Chainlink VRF v2.5 draws, batched pull claims, permissionless delayed roll, and oracle/failed-request timeout refunds.
- `BaseSepoliaFaucet`: relayer-only `claimFor`, permanent one-claim-per-wallet storage, configurable claim amount, and owner recovery.
- `VRFCoordinatorV2PlusMock`: deterministic local test coordinator. Never deploy it to a public network.

Names are limited to 3–16 UTF-8 bytes. Ball draws are 1–15; subsequent draws map uniformly across the 14 values excluding the previous ball, so ties cannot occur.

## Commands

```sh
forge install foundry-rs/forge-std@v1.9.7 OpenZeppelin/openzeppelin-contracts@v5.4.0 Vectorized/solady@v0.1.26
forge test
forge build --sizes
forge fmt --check
```

Deploy with an encrypted Foundry keystore. Never put a private key in `.env`:

```sh
export ADMIN_ADDRESS=0x...
export RELAYER_ADDRESS=0x...
export VRF_SUBSCRIPTION_ID=...
forge script script/DeployBaseSepolia.s.sol:DeployBaseSepolia \
  --rpc-url base_sepolia --account <keystore-name> --sender 0x... \
  --broadcast --verify
```

The broadcasting account must own the VRF subscription because the script registers the game as a consumer. Fund the deployed faucet separately. The coordinator and 30 gwei key hash are the official Base Sepolia VRF v2.5 values documented by Chainlink.

Base Sepolia is testnet-only. Before any mainnet or real-value deployment, obtain an independent audit, move ownership to a multisig from deployment, and review game/legal requirements.
