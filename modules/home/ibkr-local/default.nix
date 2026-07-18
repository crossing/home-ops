{ config, lib, namespace, pkgs, ... }:

let
  cfg = config.programs.ibkrLocal;
  defaultPackage = pkgs.${namespace}.ibkr-local;
  dataHome = config.xdg.dataHome;
  configHome = config.xdg.configHome;
  stateHome = config.xdg.stateHome;

  profileType = lib.types.submodule ({ name, config, ... }: {
    options = {
      ibkrProfile = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = "Profile name written to the upstream ibkr-cli config.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "IB Gateway API host.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = if config.mode == "live" then 4001 else 4002;
        description = "IB Gateway API port (4001 live, 4002 paper by default).";
      };

      clientId = lib.mkOption {
        type = lib.types.int;
        default = 1;
        description = "IB API client id.";
      };

      mode = lib.mkOption {
        type = lib.types.enum [ "paper" "live" ];
        default = "paper";
        description = "Trading mode for diagnostics and generated IBC config.";
      };

      jtsConfigDir = lib.mkOption {
        type = lib.types.str;
        default = "${configHome}/ibkr-local/jts/${name}";
        description = "Jts configuration directory mounted into IB Gateway for this profile.";
      };

      logDir = lib.mkOption {
        type = lib.types.str;
        default = "${stateHome}/ibkr-local/${name}";
        description = "Runtime log directory for this profile.";
      };

      gatewayDir = lib.mkOption {
        type = lib.types.str;
        default = "${dataHome}/ibkr/${name}/gateway";
        description = "Persistent IB Gateway install directory for this profile.";
      };

      accounts = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.str);
        default = { };
        description = "Profile-specific account groups used by ibkr-local filters.";
      };

      orderEntry = lib.mkOption {
        type = lib.types.submodule {
          options = {
            enable = lib.mkEnableOption "guarded order submission for this profile";

            ticketTtlSeconds = lib.mkOption {
              type = lib.types.ints.between 30 600;
              default = 120;
              description = "Lifetime of a prepared order ticket in seconds.";
            };

            allowedOrderTypes = lib.mkOption {
              type = lib.types.listOf (lib.types.enum [ "LMT" ]);
              default = [ "LMT" ];
              description = "Order types accepted by guarded order entry.";
            };

            allowOutsideRth = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether guarded orders may execute outside regular trading hours.";
            };
          };
        };
        default = { };
        description = "Fail-closed guarded order-entry policy.";
      };
    };
  });

  gatewayProfileType = lib.types.submodule ({ ... }: {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to generate an IB Gateway user service for this profile.";
      };

      usernameRef = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "1Password item reference for the IBKR username.";
      };

      passwordRef = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "1Password item reference for the IBKR password.";
      };

      opAccount = lib.mkOption {
        type = lib.types.str;
        default = "my.1password.com";
        description = "1Password account used for manual Gateway reauthentication.";
      };

      readOnlyLogin = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether the generated IBC config should request a read-only login.";
      };

      readOnlyApi = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether Gateway rejects API operations that require write access; ibkr-local still blocks live order mutation when disabled.";
      };

      secondFactorDevice = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Exact IBC SecondFactorDevice value to choose when multiple second factors are available.";
      };

      autoRestartTime = lib.mkOption {
        type = lib.types.strMatching "(0[1-9]|1[0-2]):[0-5][0-9] (AM|PM)";
        default = "11:45 PM";
        description = "Local weekday IBC authenticated auto-restart time in HH:MM AM/PM form.";
      };

      displayMode = lib.mkOption {
        type = lib.types.enum [ "xvfb" "x11" "visible" ];
        default = "xvfb";
        description = "Display mode passed to the ibkr-local Gateway wrapper.";
      };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra arguments passed to the ibkr-local Gateway wrapper.";
      };
    };
  });

  enabledGatewayProfiles =
    lib.filterAttrs (_: gatewayProfile: cfg.gateway.enable && gatewayProfile.enable) cfg.gateway.profiles;
  enabledExistingGatewayProfiles =
    lib.filterAttrs (name: _: builtins.hasAttr name cfg.profiles) enabledGatewayProfiles;

  mkProfileToml = name: profile: ''
    [profiles.${profile.ibkrProfile}]
    host = "${profile.host}"
    port = ${toString profile.port}
    client_id = ${toString profile.clientId}
    mode = "${profile.mode}"
  '';

  configJson = {
    defaultProfile = cfg.defaultProfile;
    accounts = cfg.accounts;
    profiles = lib.mapAttrs
      (_: profile: {
        inherit (profile)
          ibkrProfile
          host
          port
          clientId
          mode
          jtsConfigDir
          logDir
          gatewayDir
          accounts
          orderEntry
          ;
      })
      cfg.profiles;
  };

  profilesJsonFile = pkgs.writeText "ibkr-local-profiles.json" (builtins.toJSON configJson);

  ibkrCliConfig = ''
    default_profile = "${cfg.profiles.${cfg.defaultProfile}.ibkrProfile}"

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList mkProfileToml cfg.profiles)}
  '';

  mkGatewayDisplayFlag = displayMode: {
    xvfb = "--xvfb";
    x11 = "--x11";
    visible = "--visible";
  }.${displayMode};

  mkGatewayRunScript = name: gatewayProfile:
    let
      profile = cfg.profiles.${name};
      gatewayArgs = lib.escapeShellArgs (
        [
          "gateway"
          "--profile"
          name
          (mkGatewayDisplayFlag gatewayProfile.displayMode)
          "--ibc"
        ]
        ++ gatewayProfile.extraArgs
      );
    in
    pkgs.writeShellScriptBin "ibkr-gateway-run-${name}" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      if [[ -z "''${XDG_RUNTIME_DIR:-}" ]]; then
        echo "XDG_RUNTIME_DIR is required" >&2
        exit 1
      fi

      runtime_dir="$XDG_RUNTIME_DIR/ibkr-local/${name}"
      ibc_ini="$runtime_dir/ibc.ini"
      if [[ ! -f "$ibc_ini" ]]; then
        echo "missing runtime IBC config: $ibc_ini" >&2
        exit 1
      fi

      ${pkgs.coreutils}/bin/mkdir -p \
        ${lib.escapeShellArg profile.gatewayDir} \
        ${lib.escapeShellArg profile.jtsConfigDir} \
        ${lib.escapeShellArg profile.logDir}

      jts_ini=${lib.escapeShellArg "${profile.jtsConfigDir}/jts.ini"}
      if [[ -f "$jts_ini" ]]; then
        ${pkgs.gawk}/bin/awk '
          { sub(/\r$/, "") }
          /^TrustedIPs=/ {
            trusted_ip_count++
            trusted_ip_is_localhost_only = ($0 == "TrustedIPs=127.0.0.1")
          }
          END { exit !(trusted_ip_count == 1 && trusted_ip_is_localhost_only) }
        ' "$jts_ini" \
          || { echo "Gateway API trust policy is not localhost-only: $jts_ini" >&2; exit 1; }
      elif [[ -e "$jts_ini" ]]; then
        echo "Gateway API trust policy is not a regular file: $jts_ini" >&2
        exit 1
      else
        umask 077
        printf '[IBGateway]\nTrustedIPs=127.0.0.1\n' >"$jts_ini"
      fi

      export IBKR_LOCAL_PROFILES=${lib.escapeShellArg profilesJsonFile}
      export IBC_INI="$ibc_ini"
      export IBGATEWAY_DIR=${lib.escapeShellArg profile.gatewayDir}
      export IBGATEWAY_CONFIG_DIR=${lib.escapeShellArg profile.jtsConfigDir}
      export IBGATEWAY_LOG_DIR=${lib.escapeShellArg profile.logDir}
      export IBKR_CONTAINER_NAME=${lib.escapeShellArg "ibkr-gateway-${name}"}

      exec ${cfg.package}/bin/ibkr-local ${gatewayArgs}
    '';

  mkGatewayReauthScript = name: gatewayProfile:
    let
      profile = cfg.profiles.${name};
      serviceName = "ibkr-gateway-${name}.service";
      usernameRef =
        if gatewayProfile.usernameRef == null then "" else gatewayProfile.usernameRef;
      passwordRef =
        if gatewayProfile.passwordRef == null then "" else gatewayProfile.passwordRef;
      secondFactorDevice =
        if gatewayProfile.secondFactorDevice == null then "" else gatewayProfile.secondFactorDevice;
    in
    pkgs.writeShellScriptBin "ibkr-gateway-reauth-${name}" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      die() {
        echo "ibkr-gateway-reauth-${name}: $*" >&2
        exit 1
      }

      op_bin=/run/wrappers/bin/op
      [[ -x "$op_bin" ]] || die "NixOS 1Password wrapper is required at $op_bin"
      export PATH="/run/wrappers/bin:$PATH"
      safe_op_bin=$(command -v safe-op || true)
      [[ -n "$safe_op_bin" ]] || die "safe-op is required"

      if [[ -z "''${XDG_RUNTIME_DIR:-}" ]]; then
        die "XDG_RUNTIME_DIR is required"
      fi

      ${pkgs.systemd}/bin/systemctl --user -q is-active ${lib.escapeShellArg cfg.gateway.sessionTarget} \
        || die "${cfg.gateway.sessionTarget} is not active"

      runtime_base="$XDG_RUNTIME_DIR/ibkr-local"
      target_dir="$runtime_base/${name}"
      render_parent=""
      session=""
      session_env=""
      owns_target_config=0
      cleanup() {
        if [[ -n "''${session_env:-}" ]]; then
          unset "$session_env" || true
        fi
        unset session || true
        if [[ -n "''${render_parent:-}" && -d "$render_parent" ]]; then
          ${pkgs.coreutils}/bin/rm -rf "$render_parent"
        fi
        if [[ "''${owns_target_config:-0}" == 1 ]]; then
          if ${pkgs.systemd}/bin/systemctl --user -q is-active ${lib.escapeShellArg serviceName}; then
            : # The running service owns its credential config and ExecStopPost cleanup.
          else
            ${pkgs.coreutils}/bin/rm -rf "$target_dir"
          fi
        fi
      }
      trap cleanup EXIT

      ${pkgs.coreutils}/bin/mkdir -p "$runtime_base" "$target_dir"
      ${pkgs.coreutils}/bin/chmod 700 "$runtime_base" "$target_dir"
      exec 9>"$runtime_base/${name}.reauth.lock"
      ${pkgs.util-linux}/bin/flock -n 9 \
        || die "another start/reauth operation is already active for this profile"
      render_parent=$(${pkgs.coreutils}/bin/mktemp -d "$runtime_base/${name}.reauth.XXXXXX")
      ${pkgs.coreutils}/bin/chmod 700 "$render_parent"

      op_account=${lib.escapeShellArg gatewayProfile.opAccount}
      # op 2.34 returns only limited account metadata while signed out, so a
      # shorthand lookup would itself require the session we are creating.
      # The CLI's default account shorthand is the first DNS label ("my" for
      # my.1password.com), which is also the OP_SESSION_* suffix used by signin.
      account_session_key="''${op_account%%.*}"
      [[ "$account_session_key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] \
        || die "1Password account cannot form a scoped session variable"
      session_env="OP_SESSION_$account_session_key"

      if ! (
        OP_ACCOUNT="$op_account" "$op_bin" whoami --account "$op_account" >/dev/null 2>&1
      ); then
        # App-integrated op authorizes the current terminal/process tree and
        # intentionally needs no reusable token. Prefer that path first.
        "$op_bin" signin --account "$op_account" >/dev/null
        if ! OP_ACCOUNT="$op_account" "$op_bin" whoami --account "$op_account" >/dev/null 2>&1; then
          # Non-app-integrated CLI sessions still require the traditional
          # scoped token, held only in this helper process.
          session=$("$op_bin" signin --account "$op_account" --raw)
          [[ -n "$session" ]] || die "1Password sign-in did not return a scoped session"
          export "$session_env=$session"
        fi
        OP_ACCOUNT="$op_account" "$op_bin" whoami --account "$op_account" >/dev/null 2>&1 \
          || die "1Password sign-in did not authorize this terminal"
      fi

      if [[ -n "$session" ]]; then
        export "$session_env=$session"
      fi
      export OP_ACCOUNT="$op_account"

      args=(
        ibc-config
        --profile ${lib.escapeShellArg name}
        --username-ref ${lib.escapeShellArg usernameRef}
        --password-ref ${lib.escapeShellArg passwordRef}
        --trading-mode ${lib.escapeShellArg profile.mode}
        --api-port ${toString profile.port}
        --auto-restart-time ${lib.escapeShellArg gatewayProfile.autoRestartTime}
      )
      if [[ ${if gatewayProfile.readOnlyLogin then "1" else "0"} == 1 ]]; then
        args+=(--read-only-login)
      fi
      if [[ ${if gatewayProfile.readOnlyApi then "0" else "1"} == 1 ]]; then
        args+=(--allow-api-write)
      fi
      if [[ -n ${lib.escapeShellArg secondFactorDevice} ]]; then
        args+=(--second-factor-device ${lib.escapeShellArg secondFactorDevice})
      fi
      render_json=$(
        IBKR_LOCAL_PROFILES=${lib.escapeShellArg profilesJsonFile} \
        IBKR_IBC_RUNTIME_PARENT="$render_parent" \
        ${cfg.package}/bin/ibkr-local "''${args[@]}"
      )

      unset "$session_env"
      session_env=""
      session=""
      unset session

      rendered_config=$(printf '%s\n' "$render_json" | ${pkgs.jq}/bin/jq -er '.config')
      [[ -f "$rendered_config" ]] || die "rendered IBC config is missing"

      rendered_mode=$(${pkgs.coreutils}/bin/stat -c '%a' "$rendered_config")
      case "$rendered_mode" in
        600|0600)
          ;;
        *)
          die "rendered IBC config must have mode 0600"
          ;;
      esac

      rendered_trading_mode=$(
        (
          ${pkgs.gnugrep}/bin/grep -E '^TradingMode=' "$rendered_config" \
            | ${pkgs.coreutils}/bin/head -n 1 \
            | ${pkgs.coreutils}/bin/cut -d= -f2-
        ) || true
      )
      [[ -n "$rendered_trading_mode" ]] || die "rendered IBC config is missing TradingMode"
      [[ "$rendered_trading_mode" == ${lib.escapeShellArg profile.mode} ]] \
        || die "rendered IBC config TradingMode does not match profile mode"

      ${pkgs.gnugrep}/bin/grep -qx ${lib.escapeShellArg "ReadOnlyApi=${if gatewayProfile.readOnlyApi then "yes" else "no"}"} "$rendered_config" \
        || die "rendered IBC config has the wrong ReadOnlyApi policy"
      ${pkgs.gnugrep}/bin/grep -Fxq ${lib.escapeShellArg "OverrideTwsApiPort=${toString profile.port}"} "$rendered_config" \
        || die "rendered IBC config does not override Gateway's API listener to the profile port"

      if [[ ${if gatewayProfile.readOnlyLogin then "1" else "0"} == 1 ]]; then
        ${pkgs.gnugrep}/bin/grep -qx 'ReadOnlyLogin=yes' "$rendered_config" \
          || die "rendered IBC config is missing ReadOnlyLogin=yes"
      fi
      if [[ -n ${lib.escapeShellArg secondFactorDevice} ]]; then
        ${pkgs.gnugrep}/bin/grep -Fxq ${lib.escapeShellArg "SecondFactorDevice=${secondFactorDevice}"} "$rendered_config" \
          || die "rendered IBC config is missing the configured SecondFactorDevice"
      fi
      ${pkgs.gnugrep}/bin/grep -Fxq ${lib.escapeShellArg "AutoRestartTime=${gatewayProfile.autoRestartTime}"} "$rendered_config" \
        || die "rendered IBC config is missing the configured AutoRestartTime"
      ${pkgs.gnugrep}/bin/grep -qx 'ReloginAfterSecondFactorAuthenticationTimeout=no' "$rendered_config" \
        || die "rendered IBC config permits unbounded second-factor relogin"
      ${pkgs.gnugrep}/bin/grep -qx 'SecondFactorAuthenticationExitInterval=60' "$rendered_config" \
        || die "rendered IBC config is missing the second-factor exit interval"
      ${pkgs.gnugrep}/bin/grep -qx 'ExistingSessionDetectedAction=primary' "$rendered_config" \
        || die "rendered IBC config is missing the primary session policy"

      ${pkgs.systemd}/bin/systemctl --user stop ${lib.escapeShellArg serviceName} \
        || die "failed to stop the existing Gateway service"
      if ${pkgs.systemd}/bin/systemctl --user -q is-active ${lib.escapeShellArg serviceName}; then
        die "Gateway service is still active after stop"
      fi
      ${pkgs.coreutils}/bin/mkdir -p "$target_dir"
      ${pkgs.coreutils}/bin/chmod 700 "$target_dir"
      owns_target_config=1
      ${pkgs.coreutils}/bin/rm -f "$target_dir/ibc.ini"
      ${pkgs.coreutils}/bin/install -m 0600 "$rendered_config" "$target_dir/ibc.ini"
      ${pkgs.coreutils}/bin/rm -rf "$render_parent"
      render_parent=""

      if ! ${pkgs.systemd}/bin/systemctl --user start ${lib.escapeShellArg serviceName}; then
        die "failed to start the Gateway service; runtime credentials will be removed unless the service is active"
      fi
      ${pkgs.systemd}/bin/systemctl --user -q is-active ${lib.escapeShellArg serviceName} \
        || die "Gateway service did not become active; runtime credentials will be removed"
      owns_target_config=0
      echo "IB Gateway ${name} started; complete any authenticator challenge manually in the Gateway UI." >&2
    '';

  gatewayReauthScripts = lib.mapAttrsToList mkGatewayReauthScript enabledExistingGatewayProfiles;

  gatewayEnsureScript = lib.optional (cfg.gateway.ensureProfiles != [ ]) (
    pkgs.writeShellScriptBin "ibkr-gateway-ensure-live" ''
      exec ${pkgs.bash}/bin/bash ${./ibkr-gateway-ensure.sh} \
        ${lib.escapeShellArgs cfg.gateway.ensureProfiles}
    ''
  );

  mkGatewayService = name: gatewayProfile:
    let
      runScript = mkGatewayRunScript name gatewayProfile;
    in
    lib.nameValuePair "ibkr-gateway-${name}" {
      Unit = {
        Description = "Headless IB Gateway (${name})";
        After = [ cfg.gateway.sessionTarget ];
        PartOf = [ cfg.gateway.sessionTarget ];
        # Reauthentication is the only supported path that can recreate the
        # volatile runtime IBC config before starting a Gateway service.
        X-SwitchMethod = "keep-old";
      };

      Service = {
        Type = "simple";
        ExecCondition = "${pkgs.systemd}/bin/systemctl ${lib.escapeShellArgs [
          "--user"
          "-q"
          "is-active"
          cfg.gateway.sessionTarget
        ]}";
        ExecStart = "${runScript}/bin/ibkr-gateway-run-${name}";
        ExecStopPost = "${pkgs.coreutils}/bin/rm -rf %t/ibkr-local/${name}";
        Restart = "no";
        SuccessExitStatus = "143";
        # The wrapper owns a named Podman container and handles TERM by
        # stopping/removing it. Killing the entire cgroup would kill conmon
        # before Podman can perform that cleanup.
        KillMode = "process";
        TimeoutStopSec = "45s";
      };
    };

  gatewayServices = lib.mapAttrs' mkGatewayService enabledExistingGatewayProfiles;
in
{
  options.programs.ibkrLocal = {
    enable = lib.mkEnableOption "local Interactive Brokers runtime wrappers";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      defaultText = lib.literalExpression "pkgs.\${namespace}.ibkr-local";
      description = "Package providing the ibkr-local wrapper commands.";
    };

    defaultProfile = lib.mkOption {
      type = lib.types.str;
      default = "main-paper";
      description = "Default local runtime profile.";
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf profileType;
      default = { };
      description = "Local IBKR API and Gateway runtime profiles.";
    };

    accounts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = {
        margin = [ ];
        cash = [ ];
        isa = [ ];
        pension = [ ];
      };
      description = "Global account groups used by ibkr-local filters.";
    };

    gateway = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to generate headless IB Gateway user services.";
      };

      sessionTarget = lib.mkOption {
        type = lib.types.str;
        default = "graphical-session.target";
        description = "User session target that owns Gateway service lifetime.";
      };

      profiles = lib.mkOption {
        type = lib.types.attrsOf gatewayProfileType;
        default = { };
        description = "IB Gateway user services keyed by programs.ibkrLocal.profiles name.";
      };

      ensureProfiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Ordered Gateway profiles managed by ibkr-gateway-ensure-live.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      [
        {
          assertion = builtins.hasAttr cfg.defaultProfile cfg.profiles;
          message = "programs.ibkrLocal.defaultProfile must exist in programs.ibkrLocal.profiles.";
        }
      ]
      ++ (lib.mapAttrsToList
        (name: _: {
          assertion = builtins.hasAttr name cfg.profiles;
          message = "programs.ibkrLocal.gateway.profiles.${name} must also exist in programs.ibkrLocal.profiles.";
        })
        enabledGatewayProfiles)
      ++ (map
        (name: {
          assertion = builtins.hasAttr name enabledExistingGatewayProfiles;
          message = "programs.ibkrLocal.gateway.ensureProfiles entry ${name} must identify an enabled Gateway profile.";
        })
        cfg.gateway.ensureProfiles)
      ++ (lib.concatLists (lib.mapAttrsToList
        (name: gatewayProfile: [
          {
            assertion = gatewayProfile.usernameRef != null;
            message = "programs.ibkrLocal.gateway.profiles.${name}.usernameRef is required.";
          }
          {
            assertion = gatewayProfile.passwordRef != null;
            message = "programs.ibkrLocal.gateway.profiles.${name}.passwordRef is required.";
          }
        ])
        enabledGatewayProfiles));

    home.packages = [ cfg.package ] ++ gatewayReauthScripts ++ gatewayEnsureScript;

    xdg.configFile."ibkr-local/profiles.json".source = profilesJsonFile;
    xdg.configFile."ibkr-local/ibkr-cli/config.toml".text = ibkrCliConfig;

    systemd.user.services = gatewayServices;
  };
}
