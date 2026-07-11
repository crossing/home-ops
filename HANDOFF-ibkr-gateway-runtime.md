# IB Gateway runtime handoff

The runtime is Gateway-only. `packages/ibgateway` contains the Podman image definition, installer wrapper, and IBC package; `ibkr-local gateway --profile NAME --ibc` is the launch path.

Home Manager profile paths are:

- Gateway installation: `${config.xdg.dataHome}/ibkr/NAME/gateway`
- Jts configuration: `${config.xdg.configHome}/ibkr-local/jts/NAME`
- logs: `${config.xdg.stateHome}/ibkr-local/NAME`

Gateway API defaults are port 4001 for live profiles and 4002 for paper profiles. Explicit secondary ports are required when multiple profiles run simultaneously.

The integration remains read-only: data commands are retained and order submission fails closed, with preview-only behavior where supported. IBC username and password values must be read with `safe-op` into ephemeral mode-0600 configuration; authentication details and final live verification remain follow-up work.
