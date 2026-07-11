# Local IBKR integration handover

This branch provides a local-only, read-only Interactive Brokers integration built around IB Gateway, IBC, `ibkr-cli`, and `ibkr-local`.

## Architecture

- `packages/ibgateway` owns the Gateway container, installer wrapper, and packaged IBC release.
- `packages/ibkr-cli` provides read-only account and market-data commands.
- `packages/ibkr-local` selects configured profiles, launches Gateway, renders ephemeral IBC configuration, and forces order commands into preview mode.
- `modules/home/ibkr-local` generates profile configuration and per-profile Gateway user services.

The normal Gateway API ports are 4001 for live trading and 4002 for paper trading. Secondary simultaneously running profiles must use explicit distinct ports.

Credentials are rendered only through `safe-op` into mode-0600 runtime configuration. Authentication and lifecycle details are documented in `HANDOFF-ibkr-gateway-runtime.md`.
