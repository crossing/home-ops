{ config, lib, ... }:

let
  baseConfig = "${config.xdg.configHome}/ibkr-local";
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
        port = 4006;
        clientId = 11;
        mode = "paper";
        jtsConfigDir = "${baseConfig}/jts/main-paper";
        logDir = "${baseState}/main-paper";
        accounts = {
          margin = [ ];
          cash = [ ];
          isa = [ ];
        };
        orderEntry.enable = true;
      };

      main-live = {
        port = 4005;
        clientId = 12;
        mode = "live";
        jtsConfigDir = "${baseConfig}/jts/main-live";
        logDir = "${baseState}/main-live";
        accounts = {
          margin = [ ];
          cash = [ ];
          isa = [ ];
        };
        orderEntry.enable = true;
      };

      pension-paper = {
        port = 4004;
        clientId = 21;
        mode = "paper";
        jtsConfigDir = "${baseConfig}/jts/pension-paper";
        logDir = "${baseState}/pension-paper";
        accounts.pension = [ ];
      };

      pension-live = {
        port = 4003;
        clientId = 22;
        mode = "live";
        jtsConfigDir = "${baseConfig}/jts/pension-live";
        logDir = "${baseState}/pension-live";
        accounts.pension = [ ];
        orderEntry.enable = true;
      };
    };

    gateway = {
      enable = true;
      ensureProfiles = [ "main-live" "pension-live" ];
      profiles = {
        main-live = {
          usernameRef = "op://3eyhyuvr6x6hvvajthxk5cn37u/3drrbjgoksyc3tuu4yxyvshjvq/username";
          passwordRef = "op://3eyhyuvr6x6hvvajthxk5cn37u/3drrbjgoksyc3tuu4yxyvshjvq/password";
          displayMode = "xvfb";
          readOnlyApi = false;
          readOnlyLogin = false;
          secondFactorDevice = "IB Key";
          autoRestartTime = "11:35 PM";
        };

        pension-live = {
          usernameRef = "op://3eyhyuvr6x6hvvajthxk5cn37u/6jya6jb3uvmvbweziwn6xhcloa/username";
          passwordRef = "op://3eyhyuvr6x6hvvajthxk5cn37u/6jya6jb3uvmvbweziwn6xhcloa/password";
          displayMode = "xvfb";
          readOnlyApi = false;
          readOnlyLogin = false;
          secondFactorDevice = "IB Key";
          autoRestartTime = "11:55 PM";
        };
      };
    };
  };
}
