{ config, lib, pkgs, ... }:
{
  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCrrDZanBQstaO8cKN71nqbw3UrLC7n0U8k43+xNXriK9DqAPOIRuMfc0WY1SpqtnnVZXCEeYs4rh60GkYsuMj2uB81mzRtezrn4dnUO2VeGa91fLA0vPqtcegYTNJsfEA+GPfAS84f+kTJcy9BDO7oItcZbAE1HnolT0FvRJjRcyAybadxAxsK8LhNEIL1n7/NM82KhI1MiQBuihIlbsTgEtiFJSjt131ytW4FO+gcwDUbs+a54AdhW8qY3mCLSWN/dd48vPb9t6de6euDPslJ20y4Q8V7YfQszLRTIKqcXy655DXmEeT0IwdlZQsBppuB+/goH/EUELPucOWhy+ulUEOrkPztACUeURUmnq84vWZ/KTgxoYTz0+KEydDMAcw48yqfTr7reUteh8tSpy5Zz8HDSACkgdd+EaZeNZyOPqZoTz6j1dKMM4BHdO/zpKwr9od/Osm21B/A+KeisjjEX5B8L7IKYD+KsOQmUyqPqTtLNGYnhhn5Q0RSFypO6A0= xing@qit"
  ];
}
