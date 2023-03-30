{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    rclone
    rclone-browser
  ];

  systemd.user.services.rclone =
    let
      mountTarget = "${config.home.homeDirectory}/Documents/Google";
      configFile = config.sops.secrets."rclone.conf".path;
      cacheDir = "${config.xdg.cacheHome}/rclone";
      rcloneWrapper = pkgs.writeShellScriptBin "rclonew" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail
        mkdir -p ${mountTarget} ${cacheDir}
        exec ${pkgs.rclone}/bin/rclone \
            mount Drive:// ${mountTarget} \
            --config ${configFile} \
            --cache-dir ${cacheDir} \
            --vfs-cache-mode=full
      '';
    in
    {
      Unit = {
        Description = "RClone Google Drive";
        After = [ "sops-nix.service" ];
      };

      Install = {
        WantedBy = [ "default.target" ];
      };

      Service = {
        Type = "notify";
        ExecStart = "${rcloneWrapper}/bin/rclonew";
      };
    };
}
