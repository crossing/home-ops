{ config, lib, namespace, pkgs, ... }:

let
  cfg = config.programs.ibkrLocal;
  defaultPackage = pkgs.${namespace}.ibkr-local;

  profileType = lib.types.submodule ({ name, ... }: {
    options = {
      ibkrProfile = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = "Profile name written to the upstream ibkr-cli config.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "TWS or IB Gateway API host.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        description = "TWS or IB Gateway API port.";
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

      twsDir = lib.mkOption {
        type = lib.types.str;
        default = "${config.xdg.dataHome}/ibkr/${name}/tws";
        description = "Persistent TWS install directory for this profile.";
      };

      jtsConfigDir = lib.mkOption {
        type = lib.types.str;
        default = "${config.xdg.configHome}/ibkr-local/jts/${name}";
        description = "Jts configuration directory mounted into TWS for this profile.";
      };

      logDir = lib.mkOption {
        type = lib.types.str;
        default = "${config.xdg.stateHome}/ibkr-local/${name}";
        description = "Runtime log directory for this profile.";
      };

      gatewayDir = lib.mkOption {
        type = lib.types.str;
        default = "${config.xdg.dataHome}/ibkr/${name}/gateway";
        description = "Persistent IB Gateway install directory for this profile.";
      };

      gatewayJtsConfigDir = lib.mkOption {
        type = lib.types.str;
        default = "${config.xdg.configHome}/ibkr-local/gateway-jts/${name}";
        description = "Jts configuration directory mounted into IB Gateway for this profile.";
      };

      gatewayLogDir = lib.mkOption {
        type = lib.types.str;
        default = "${config.xdg.stateHome}/ibkr-local/gateway/${name}";
        description = "Runtime IB Gateway log directory for this profile.";
      };

      accounts = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.str);
        default = { };
        description = "Profile-specific account groups used by ibkr-local filters.";
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
        default = true;
        description = "Whether the generated IBC config should request a read-only login.";
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
    profiles = lib.mapAttrs (_: profile: {
      inherit (profile)
        ibkrProfile
        host
        port
        clientId
        mode
        twsDir
        jtsConfigDir
        logDir
        gatewayDir
        gatewayJtsConfigDir
        gatewayLogDir
        accounts
        ;
    }) cfg.profiles;
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
        ${lib.escapeShellArg profile.gatewayJtsConfigDir} \
        ${lib.escapeShellArg profile.gatewayLogDir}

      export IBKR_LOCAL_PROFILES=${lib.escapeShellArg profilesJsonFile}
      export IBC_INI="$ibc_ini"
      export IBGATEWAY_DIR=${lib.escapeShellArg profile.gatewayDir}
      export IBGATEWAY_CONFIG_DIR=${lib.escapeShellArg profile.gatewayJtsConfigDir}
      export IBGATEWAY_LOG_DIR=${lib.escapeShellArg profile.gatewayLogDir}

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
    in
    pkgs.writeShellScriptBin "ibkr-gateway-reauth-${name}" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      die() {
        echo "ibkr-gateway-reauth-${name}: $*" >&2
        exit 1
      }

      ${pkgs.systemd}/bin/systemctl --user stop ${lib.escapeShellArg serviceName} || true

      op_bin=$(command -v op || true)
      [[ -n "$op_bin" ]] || die "op is required"

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

      cleanup() {
        if [[ -n "''${session_env:-}" ]]; then
          unset "$session_env" || true
        fi
        unset session || true
        if [[ -n "''${render_parent:-}" && -d "$render_parent" ]]; then
          ${pkgs.coreutils}/bin/rm -rf "$render_parent"
        fi
      }
      trap cleanup EXIT

      ${pkgs.coreutils}/bin/mkdir -p "$runtime_base" "$target_dir"
      ${pkgs.coreutils}/bin/chmod 700 "$runtime_base" "$target_dir"
      ${pkgs.coreutils}/bin/rm -f "$target_dir/ibc.ini"
      render_parent=$(${pkgs.coreutils}/bin/mktemp -d "$runtime_base/${name}.reauth.XXXXXX")
      ${pkgs.coreutils}/bin/chmod 700 "$render_parent"

      op_account=${lib.escapeShellArg gatewayProfile.opAccount}
      session=$("$op_bin" signin --account "$op_account" --raw)

      for candidate in OP_SESSION_my OP_SESSION_my_1password_com OP_SESSION_my_1password; do
        if (
          export "$candidate=$session"
          OP_ACCOUNT="$op_account" "$op_bin" whoami --account "$op_account" >/dev/null 2>&1
        ); then
          session_env="$candidate"
          break
        fi
      done
      [[ -n "$session_env" ]] || die "could not find a valid OP_SESSION_* environment name"

      export "$session_env=$session"
      export OP_ACCOUNT="$op_account"

      args=(
        ibc-config
        --profile ${lib.escapeShellArg name}
        --username-ref ${lib.escapeShellArg usernameRef}
        --password-ref ${lib.escapeShellArg passwordRef}
        --trading-mode ${lib.escapeShellArg profile.mode}
      )
      if [[ ${if gatewayProfile.readOnlyLogin then "1" else "0"} == 1 ]]; then
        args+=(--read-only-login)
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
      ${pkgs.coreutils}/bin/install -m 0600 "$rendered_config" "$target_dir/ibc.ini"
      ${pkgs.coreutils}/bin/rm -rf "$render_parent"
      render_parent=""

      ${pkgs.systemd}/bin/systemctl --user start ${lib.escapeShellArg serviceName}
    '';

  gatewayReauthScripts = lib.mapAttrsToList mkGatewayReauthScript enabledExistingGatewayProfiles;

  mkGatewayService = name: gatewayProfile:
    let
      runScript = mkGatewayRunScript name gatewayProfile;
    in
    lib.nameValuePair "ibkr-gateway-${name}" {
      Unit = {
        Description = "Headless IB Gateway (${name})";
        After = [ cfg.gateway.sessionTarget ];
        PartOf = [ cfg.gateway.sessionTarget ];
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
        KillMode = "mixed";
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
      description = "Local IBKR API/TWS runtime profiles.";
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

    home.packages = [ cfg.package ] ++ gatewayReauthScripts;

    xdg.configFile."ibkr-local/profiles.json".source = profilesJsonFile;
    xdg.configFile."ibkr-local/ibkr-cli/config.toml".text = ibkrCliConfig;

    systemd.user.services = gatewayServices;
  };
}
