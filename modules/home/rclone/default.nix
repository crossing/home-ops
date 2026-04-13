{ config, lib, pkgs, ... }:
let
  cfg = config.services.rcloneMounts;
  enabledMounts = lib.filterAttrs (_: mountCfg: mountCfg.enable) cfg.mounts;
  remoteWithPath = mountCfg:
    if mountCfg.remotePath == "" then
      "${mountCfg.remote}:"
    else
      "${mountCfg.remote}:${mountCfg.remotePath}";
  mkMountService = name: mountCfg:
    let
      mountTarget = mountCfg.mountPoint;
      cacheDir = mountCfg.cacheDir;
      rcloneArgs = lib.escapeShellArgs (
        [
          "mount"
          (remoteWithPath mountCfg)
          mountTarget
          "--config"
          cfg.configPath
          "--cache-dir"
          cacheDir
          "--vfs-cache-mode"
          mountCfg.vfsCacheMode
        ]
        ++ mountCfg.extraArgs
      );
      rcloneWrapper = pkgs.writeShellScriptBin "rclone-mount-${name}" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail
        ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg mountTarget} ${lib.escapeShellArg cacheDir}
        exec ${pkgs.rclone}/bin/rclone ${rcloneArgs}
      '';
      conditionScript = pkgs.writeShellScript "rclone-mount-${name}-condition" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail
        test -f ${lib.escapeShellArg cfg.configPath}
        ${pkgs.rclone}/bin/rclone listremotes --config ${lib.escapeShellArg cfg.configPath} | \
          ${pkgs.gnugrep}/bin/grep -qx ${lib.escapeShellArg "${mountCfg.remote}:"}
      '';
    in
    lib.nameValuePair "rclone-mount-${name}" {
      Unit = {
        Description = "RClone mount (${name})";
        ConditionPathExists = cfg.configPath;
      };

      Install = {
        WantedBy = [ "default.target" ];
      };

      Service = {
        Type = "notify";
        ExecCondition = conditionScript;
        ExecStart = "${rcloneWrapper}/bin/rclone-mount-${name}";
        Environment = [ "PATH=/run/wrappers/bin" ];
      };
    };
in
{
  options.services.rcloneMounts = {
    enable = lib.mkEnableOption "Enable rclone mount services.";

    configPath = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.configHome}/rclone/rclone.conf";
      description = "Path to the rclone configuration generated via interactive setup.";
    };

    mounts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to enable this rclone mount.";
          };

          remote = lib.mkOption {
            type = lib.types.str;
            default = name;
            description = "Remote name created in rclone config.";
          };

          remotePath = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Optional remote path to mount.";
          };

          mountPoint = lib.mkOption {
            type = lib.types.str;
            description = "Local filesystem path to mount the remote.";
          };

          cacheDir = lib.mkOption {
            type = lib.types.str;
            default = "${config.xdg.cacheHome}/rclone/${name}";
            description = "Cache directory for the mount.";
          };

          vfsCacheMode = lib.mkOption {
            type = lib.types.str;
            default = "full";
            description = "Rclone vfs cache mode.";
          };

          extraArgs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Extra arguments passed to rclone mount.";
          };
        };
      }));
      default = { };
      description = "Rclone mounts keyed by name.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.rclone
      pkgs.rclone-browser
    ];

    systemd.user.services = lib.mapAttrs' mkMountService enabledMounts;
  };
}
