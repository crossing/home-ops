{ config, lib, pkgs, ... }:

let
  cfg = config.services.unifi-os-server;
  inherit (lib) mkEnableOption mkIf mkOption types;

  volumes = {
    uosserver_persistent = "/persistent";
    uosserver_var_log = "/var/log";
    uosserver_data = "/data";
    uosserver_srv = "/srv";
    uosserver_etc_rabbitmq_ssl = "/etc/rabbitmq/ssl";
    uosserver_var_lib_mongodb = "/var/lib/mongodb";
    uosserver_var_lib_unifi = "/var/lib/unifi";
  };

  podmanEnvironment = {
    HOME = "/var/lib/uosserver";
    XDG_RUNTIME_DIR = "/run/uosserver";
  };

  publishArgs = [
    "--publish=9543:9543/tcp"
    "--publish=28082:28082/tcp"
    "--publish=5671:5671/tcp"
    "--publish=6789:6789/tcp"
    "--publish=8080:8080/tcp"
    "--publish=8444:8444/tcp"
    "--publish=8880:8880/tcp"
    "--publish=8881:8881/tcp"
    "--publish=8882:8882/tcp"
    "--publish=3478:3478/udp"
    "--publish=5514:5514/udp"
    "--publish=10003:10003/udp"
    "--publish=127.0.0.1:11084:11084/tcp"
    "--publish=${toString cfg.webPort}:443/tcp"
  ];

  volumeArgs = lib.mapAttrsToList (name: mount: "--volume=${name}:${mount}") volumes;

  containerArgs = [
    "run"
    "--name=uosserver"
    "--pull=never"
    "--pids-limit=65536"
    "--systemd=always"
    "--cgroup-manager=cgroupfs"
    "--network=pasta:--ns-ifname,eth0,--map-host-loopback,203.0.113.113,--dns-forward,203.0.113.113"
    "--add-host=host.docker.internal:203.0.113.113"
    "--add-host=host.containers.internal:203.0.113.113"
    "--dns=203.0.113.113"
    "--cap-add=NET_RAW"
    "--cap-add=NET_ADMIN"
    "--env-file=/var/lib/uosserver/environment"
    "--env=APP_VERSION=${cfg.package.version}"
    "--env=APP_MODEL=UOSSERVER"
    "--env=PRODUCT_NAME=UniFi OS Server"
    "--env=FIRMWARE_PLATFORM=linux-x64"
  ] ++ volumeArgs ++ publishArgs ++ [ cfg.package.imageReference ];

  runContainer = pkgs.writeShellScript "run-unifi-os-server" ''
    set -euo pipefail

    for attempt in $(seq 1 5); do
      podman rm --force --ignore uosserver
      if podman ${lib.escapeShellArgs containerArgs}; then
        exit 0
      else
        status=$?
      fi

      if [[ "$status" -ne 126 || "$attempt" -eq 5 ]]; then
        exit "$status"
      fi

      echo "podman networking failed during startup; retrying in 2 seconds" >&2
      sleep 2
    done
  '';

  waitForHealth = pkgs.writeShellScript "wait-for-unifi-os-server" ''
    set -euo pipefail
    not_running=0
    for _ in $(seq 1 120); do
      if curl --insecure --fail --silent --show-error \
        https://127.0.0.1:${toString cfg.webPort}/ >/dev/null; then
        exit 0
      fi

      running=$(podman inspect --format '{{.State.Running}}' uosserver 2>/dev/null || true)
      if [[ "$running" == true ]]; then
        not_running=0
      else
        not_running=$((not_running + 1))
        if [[ "$not_running" -ge 10 ]]; then
          echo "UniFi OS Server container is not running" >&2
          exit 1
        fi
      fi
      sleep 2
    done
    echo "UniFi OS Server did not become ready within 240 seconds" >&2
    exit 1
  '';
in
{
  options.services.unifi-os-server = {
    enable = mkEnableOption "declarative rootless UniFi OS Server";

    package = mkOption {
      type = types.package;
      description = "Pinned UniFi OS Server package containing the OCI archive";
    };

    webPort = mkOption {
      type = types.port;
      default = 11443;
      description = "Host TCP port mapped to the UniFi OS HTTPS service";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the required UniFi Network LAN ports";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !(builtins.elem "ipv6.disable=1" config.boot.kernelParams);
        message = "UniFi OS Server requires IPv6 kernel support";
      }
    ];

    virtualisation.podman.enable = true;

    environment.systemPackages = [ cfg.package ];

    users.users.uosserver = {
      isSystemUser = true;
      group = "uosserver";
      home = "/var/lib/uosserver";
      createHome = true;
      subUidRanges = [
        {
          startUid = 100000;
          count = 65536;
        }
      ];
      subGidRanges = [
        {
          startGid = 100000;
          count = 65536;
        }
      ];
    };
    users.groups.uosserver = { };

    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall [
      6789
      8080
      8444
      8880
      8881
      8882
      cfg.webPort
      28082
    ];
    networking.firewall.allowedUDPPorts = lib.optionals cfg.openFirewall [
      3478
      5514
      10003
    ];

    systemd.services.unifi-os-server-prepare = {
      description = "Prepare the rootless UniFi OS Server image and volumes";
      before = [ "unifi-os-server.service" ];
      requiredBy = [ "unifi-os-server.service" ];
      path = [
        "/run/wrappers"
        pkgs.coreutils
        pkgs.podman
        pkgs.util-linux
      ];
      environment = podmanEnvironment;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "uosserver";
        Group = "uosserver";
        StateDirectory = "uosserver";
        StateDirectoryMode = "0750";
        RuntimeDirectory = "uosserver";
        RuntimeDirectoryMode = "0700";
        RuntimeDirectoryPreserve = "yes";
      };
      script = ''
        set -euo pipefail

        environment_file=/var/lib/uosserver/environment
        existing_uuid=
        if [[ -s "$environment_file" ]]; then
          while IFS= read -r line; do
            case "$line" in
              UOS_UUID=*) existing_uuid="''${line#UOS_UUID=}" ;;
            esac
          done <"$environment_file"
        fi

        uos_uuid="$existing_uuid"

        # Current UniFi Network builds require the emulated hardware UUID to
        # be version 5. Preserve valid identities and map legacy values once.
        if [[ ! "$existing_uuid" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-5[0-9A-Fa-f]{3}-[89ABab][0-9A-Fa-f]{3}-[0-9A-Fa-f]{12}$ ]]; then
          seed="$existing_uuid"
          if [[ -z "$seed" ]]; then
            seed=$(uuidgen)
          fi
          uos_uuid=$(uuidgen --sha1 --namespace @dns --name "unifi-os-server:$seed")
          umask 077
          printf 'UOS_UUID=%s\n' "$uos_uuid" >"$environment_file.new"
          mv "$environment_file.new" "$environment_file"
        fi
        chmod 0600 "$environment_file"

        image_reference=${lib.escapeShellArg cfg.package.imageReference}
        expected_id=${lib.escapeShellArg cfg.package.imageId}
        loaded_id=$(podman image inspect --format '{{.Id}}' "$image_reference" 2>/dev/null || true)
        loaded_id="''${loaded_id#sha256:}"
        if [[ "$loaded_id" != "$expected_id" ]]; then
          podman load --input ${lib.escapeShellArg cfg.package.image}
          loaded_id=$(podman image inspect --format '{{.Id}}' "$image_reference")
          loaded_id="''${loaded_id#sha256:}"
        fi
        if [[ "$loaded_id" != "$expected_id" ]]; then
          echo "loaded UniFi OS Server image ID does not match the Nix pin" >&2
          exit 1
        fi

        ${lib.concatMapStringsSep "\n" (name: ''
          if ! podman volume exists ${lib.escapeShellArg name}; then
            podman volume create ${lib.escapeShellArg name} >/dev/null
          fi
        '') (builtins.attrNames volumes)}

        # UniFi copies UOS_UUID into /data on first boot. Repair only a legacy
        # cached value; an existing valid v5 UUID remains authoritative.
        data_mount=$(podman volume inspect --format '{{.Mountpoint}}' uosserver_data)
        cached_uuid_file="$data_mount/uos_uuid"
        if [[ -e "$cached_uuid_file" ]]; then
          cached_uuid=
          IFS= read -r cached_uuid <"$cached_uuid_file" || true
          if [[ ! "$cached_uuid" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-5[0-9A-Fa-f]{3}-[89ABab][0-9A-Fa-f]{3}-[0-9A-Fa-f]{12}$ ]]; then
            umask 022
            printf '%s\n' "$uos_uuid" >"$cached_uuid_file.new"
            chmod 0644 "$cached_uuid_file.new"
            mv "$cached_uuid_file.new" "$cached_uuid_file"
          fi
        fi
      '';
    };

    systemd.services.unifi-os-server = {
      description = "UniFi OS Server";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "unifi-os-server-prepare.service"
      ];
      requires = [ "unifi-os-server-prepare.service" ];
      path = [
        "/run/wrappers"
        pkgs.aardvark-dns
        pkgs.netavark
        pkgs.passt
        pkgs.podman
        pkgs.slirp4netns
        pkgs.curl
      ];
      environment = podmanEnvironment;
      serviceConfig = {
        Type = "simple";
        User = "uosserver";
        Group = "uosserver";
        ExecStart = runContainer;
        ExecStartPost = waitForHealth;
        ExecStop = "${pkgs.podman}/bin/podman stop --time 120 uosserver";
        Restart = "on-failure";
        RestartSec = 10;
        TimeoutStartSec = 300;
        TimeoutStopSec = 180;
        TimeoutStopFailureMode = "kill";
        Delegate = true;
        StateDirectory = "uosserver";
        StateDirectoryMode = "0750";
        RuntimeDirectory = "uosserver";
        RuntimeDirectoryMode = "0700";
        RuntimeDirectoryPreserve = "yes";
      };
      unitConfig = {
        StartLimitIntervalSec = 60;
        StartLimitBurst = 3;
      };
    };
  };
}
