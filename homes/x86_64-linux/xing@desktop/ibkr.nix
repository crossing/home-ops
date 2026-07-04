{ config, lib, ... }:

let
  baseConfig = "${config.xdg.configHome}/ibkr-local";
  baseData = "${config.xdg.dataHome}/ibkr";
  baseState = "${config.xdg.stateHome}/ibkr-local";
in
lib.mkIf config.profiles.personal.enable {
  programs.ibkrLocal = {
    enable = true;
    defaultProfile = "main-paper";

    accounts = {
      margin = [ ];
      cash = [ ];
      isa = [ ];
      pension = [ ];
    };

    profiles = {
      main-paper = {
        port = 7497;
        clientId = 11;
        mode = "paper";
        twsDir = "${baseData}/main-paper/tws";
        jtsConfigDir = "${baseConfig}/jts/main-paper";
        logDir = "${baseState}/main-paper";
        accounts = {
          margin = [ ];
          cash = [ ];
          isa = [ ];
        };
      };

      main-live = {
        port = 7496;
        clientId = 12;
        mode = "live";
        twsDir = "${baseData}/main-live/tws";
        jtsConfigDir = "${baseConfig}/jts/main-live";
        logDir = "${baseState}/main-live";
        accounts = {
          margin = [ ];
          cash = [ ];
          isa = [ ];
        };
      };

      pension-paper = {
        port = 7507;
        clientId = 21;
        mode = "paper";
        twsDir = "${baseData}/pension-paper/tws";
        jtsConfigDir = "${baseConfig}/jts/pension-paper";
        logDir = "${baseState}/pension-paper";
        accounts.pension = [ ];
      };

      pension-live = {
        port = 7506;
        clientId = 22;
        mode = "live";
        twsDir = "${baseData}/pension-live/tws";
        jtsConfigDir = "${baseConfig}/jts/pension-live";
        logDir = "${baseState}/pension-live";
        accounts.pension = [ ];
      };
    };

    gateway = {
      enable = true;
      profiles.main-live = {
        usernameRef = "op://Private/3drrbjgoksyc3tuu4yxyvshjvq/username";
        passwordRef = "op://Private/3drrbjgoksyc3tuu4yxyvshjvq/password";
        readOnlyLogin = true;
      };
    };
  };
}
