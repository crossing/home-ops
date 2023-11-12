{ config, pkgs, lib, ... }:
{
  programs.git = {
    enable = true;
    package = pkgs.git.override {
      withLibsecret = true;
    };

    lfs.enable = true;

    extraConfig = {
      credential.helper = "libsecret";
      push.autoSetupRemote = true;
      pull.rebase = true;
      rebase.autoStash = true;
    };

    includes = [
      { inherit (config.sops.secrets.git_user_inc) path; }
    ];
  };

  programs.gh = {
    enable = true;
    enableGitCredentialHelper = true;
  };
}
