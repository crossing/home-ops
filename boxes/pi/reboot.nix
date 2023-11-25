{ ... }:
{
  systemd.timers.reboot = {
    timerConfig = {
      OnCalendar = "04:00";
      Unit = "reboot.target";
    };
    wantedBy = [ "timers.target" ];
  };
}
