{ pkgs, inputs, ... }:

{
  services.unifi-os-server = {
    enable = true;
    package = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.unifi-os-server;
    webPort = 8443;
    openFirewall = true;
  };
}
