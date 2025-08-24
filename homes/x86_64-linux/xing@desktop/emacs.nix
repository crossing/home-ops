{ config, pkgs, lib, ... }:
{
  home.packages = [
    pkgs.emacs
  ];

  home.sessionVariables = {
    EDITOR = "emacs";
  };

  programs.zsh = {
    initExtraBeforeCompInit = ''
      # emacs
      if [ ! -d $HOME/.emacs.d ]; then
          git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d
      fi

      pushd -q $HOME/.emacs.d
      _sm_branch=$(git rev-parse --abbrev-ref HEAD)
      [[ $_sm_branch = "develop" ]] || git checkout develop
      popd -q
    '';

    oh-my-zsh.plugins = [
      "emacs"
    ];
  };

  home.file."${config.home.homeDirectory}/.spacemacs.d/init.el" = {
    source = ./files/spacemacs.d/init.el;
  };
}
