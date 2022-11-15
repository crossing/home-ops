{ config, pkgs, lib, ... }:
{
  programs.git = {
    enable = true;
    package = pkgs.git.override {
      withLibsecret = true;
    };

    userName = "Xing Yang";
    userEmail = "xor@jecity.net";

    lfs.enable = true;

    extraConfig = {
      credential.helper = "libsecret";
      pull.rebase = true;
      rebase.autoStash = true;
    };
  };

  programs.gh = {
    enable = true;
    enableGitCredentialHelper = true;
  };
}
