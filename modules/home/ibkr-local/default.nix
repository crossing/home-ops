{ config, inputs, lib, pkgs, ... }:

let
  cfg = config.programs.ibkrLocal;
  defaultPackage = pkgs.callPackage ../../../packages/ibkr-local { inherit inputs; };

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

      accounts = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.str);
        default = { };
        description = "Profile-specific account groups used by ibkr-local filters.";
      };
    };
  });

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
      inherit (profile) ibkrProfile host port clientId mode twsDir jtsConfigDir logDir accounts;
    }) cfg.profiles;
  };

  ibkrCliConfig = ''
    default_profile = "${cfg.profiles.${cfg.defaultProfile}.ibkrProfile}"

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList mkProfileToml cfg.profiles)}
  '';
in
{
  options.programs.ibkrLocal = {
    enable = lib.mkEnableOption "local Interactive Brokers runtime wrappers";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      defaultText = lib.literalExpression "pkgs.callPackage ../../../packages/ibkr-local { inherit inputs; }";
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
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.hasAttr cfg.defaultProfile cfg.profiles;
        message = "programs.ibkrLocal.defaultProfile must exist in programs.ibkrLocal.profiles.";
      }
    ];

    home.packages = [
      cfg.package
    ];

    xdg.configFile."ibkr-local/profiles.json".text = builtins.toJSON configJson;
    xdg.configFile."ibkr-local/ibkr-cli/config.toml".text = ibkrCliConfig;
  };
}
