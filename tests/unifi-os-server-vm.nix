{ pkgs, flake }:

let
  package = flake.packages.x86_64-linux.unifi-os-server;
  podmanAsUosserver =
    "runuser -u uosserver -- env HOME=/var/lib/uosserver "
    + "XDG_RUNTIME_DIR=/run/uosserver podman";
  volumes = [
    "uosserver_persistent"
    "uosserver_var_log"
    "uosserver_data"
    "uosserver_srv"
    "uosserver_etc_rabbitmq_ssl"
    "uosserver_var_lib_mongodb"
    "uosserver_var_lib_unifi"
  ];
in
pkgs.testers.runNixOSTest {
  name = "unifi-os-server-vm";

  nodes.machine = { pkgs, ... }: {
    imports = [ ../modules/nixos/unifi-os-server/default.nix ];

    virtualisation = {
      memorySize = 4096;
      diskSize = 20480;
    };

    services.unifi-os-server = {
      enable = true;
      inherit package;
      webPort = 11443;
      openFirewall = true;
    };

    environment.systemPackages = [ pkgs.curl ];

    # NixOS VM tests replace the host filesystem and discard swapDevices.
    systemd.services.vm-swap = {
      description = "Create swap for the UniFi OS Server VM test";
      wantedBy = [ "multi-user.target" ];
      before = [ "unifi-os-server-prepare.service" ];
      path = [ pkgs.coreutils pkgs.util-linux ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        fallocate -l 2G /var/lib/swapfile
        chmod 0600 /var/lib/swapfile
        mkswap /var/lib/swapfile
        swapon /var/lib/swapfile
      '';
    };
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("vm-swap.service")
    machine.wait_for_unit("unifi-os-server-prepare.service", timeout=300)
    machine.succeed(
        "grep -Eq '^UOS_UUID=[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-"
        "[89ab][0-9a-f]{3}-[0-9a-f]{12}$' /var/lib/uosserver/environment"
    )
    machine.wait_for_unit("unifi-os-server.service", timeout=300)
    machine.succeed(
        "test \"$(systemctl show --property=TimeoutStopFailureMode --value "
        "unifi-os-server.service)\" = kill"
    )
    machine.wait_until_succeeds(
        "curl -kfsS https://127.0.0.1:11443/ >/dev/null", timeout=240
    )

    # A stale pasta process can briefly retain a published port while the
    # container is recreated during boot. The unit must retry that transient
    # podman exit instead of spending its full health timeout in start-post.
    machine.succeed("systemctl stop unifi-os-server.service", timeout=240)
    machine.succeed(
        "systemd-run --unit=unifi-port-conflict "
        "${pkgs.socat}/bin/socat TCP-LISTEN:11084,bind=127.0.0.1,reuseaddr "
        "OPEN:/dev/null"
    )
    machine.wait_until_succeeds("ss -ltn | grep -q ':11084 '")
    machine.succeed(
        "systemd-run --unit=unifi-port-release --on-active=4s "
        "systemctl stop unifi-port-conflict.service"
    )
    machine.execute("systemctl start --no-block unifi-os-server.service")
    machine.wait_for_unit("unifi-os-server.service", timeout=60)
    machine.wait_until_succeeds(
        "curl -kfsS https://127.0.0.1:11443/ >/dev/null", timeout=60
    )

    expected_volumes = ${builtins.toJSON volumes}
    actual_volumes = machine.succeed(
        "${podmanAsUosserver} volume ls --format '{{.Name}}' | sort"
    ).splitlines()
    assert actual_volumes == sorted(expected_volumes), actual_volumes

    original_container = machine.succeed(
        "${podmanAsUosserver} inspect --format '{{.Id}}' uosserver"
    ).strip()
    machine.succeed(
        "volume=$(${podmanAsUosserver} volume inspect --format '{{.Mountpoint}}' "
        "uosserver_persistent); "
        "runuser -u uosserver -- sh -c 'printf persisted > \"$1/codex-marker\"' sh \"$volume\""
    )

    machine.succeed("systemctl restart unifi-os-server.service", timeout=240)
    machine.wait_until_succeeds(
        "curl -kfsS https://127.0.0.1:11443/ >/dev/null", timeout=240
    )
    recreated_container = machine.succeed(
        "${podmanAsUosserver} inspect --format '{{.Id}}' uosserver"
    ).strip()
    assert recreated_container != original_container
    machine.succeed(
        "volume=$(${podmanAsUosserver} volume inspect --format '{{.Mountpoint}}' "
        "uosserver_persistent); grep -x persisted \"$volume/codex-marker\""
    )

    machine.shutdown()
    machine.start()
    machine.wait_for_unit("unifi-os-server.service", timeout=300)
    machine.wait_until_succeeds(
        "curl -kfsS https://127.0.0.1:11443/ >/dev/null", timeout=240
    )
    machine.succeed(
        "volume=$(${podmanAsUosserver} volume inspect --format '{{.Mountpoint}}' "
        "uosserver_persistent); grep -x persisted \"$volume/codex-marker\""
    )

    # Releases before this test used uuidgen's default version-4 UUID. The
    # preparation unit must upgrade that identity deterministically because
    # current UniFi Network builds only accept a version-5 hardware UUID.
    machine.succeed("systemctl stop unifi-os-server.service", timeout=240)
    machine.succeed("systemctl stop unifi-os-server-prepare.service")
    machine.succeed(
        "printf 'UOS_UUID=00000000-0000-4000-8000-000000000000\\n' "
        ">/var/lib/uosserver/environment; "
        "chown uosserver:uosserver /var/lib/uosserver/environment"
    )
    machine.succeed(
        "volume=$(${podmanAsUosserver} volume inspect --format '{{.Mountpoint}}' "
        "uosserver_data); runuser -u uosserver -- sh -c "
        "'printf \"00000000-0000-4000-8000-000000000000\\n\" >\"$1/uos_uuid\"' "
        "sh \"$volume\""
    )
    machine.succeed("systemctl start unifi-os-server-prepare.service", timeout=300)
    machine.succeed(
        "grep -x 'UOS_UUID=783f1092-3c59-510c-9cb8-2f8f77130691' "
        "/var/lib/uosserver/environment"
    )
    machine.succeed(
        "volume=$(${podmanAsUosserver} volume inspect --format '{{.Mountpoint}}' "
        "uosserver_data); grep -x '783f1092-3c59-510c-9cb8-2f8f77130691' "
        "\"$volume/uos_uuid\""
    )
  '';
}
