#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: tws [--visible|--x11|--xvfb] [--ibc] [--screenshot-only] [tws args...]

Modes:
  --visible          Use the current desktop session. This is the default.
  --x11              Use the current X11 DISPLAY and force GDK_BACKEND=x11.
  --xvfb             Start a virtual X11 display with xvfb-run, then launch TWS.
  --ibc              Start TWS through IBC; requires external IBC config.

Environment:
  TWS_DIR            Persistent TWS install directory.
  CONFIG_DIR         Persistent Jts config directory.
  TWS_LOG_DIR        Host log directory mounted into the container.
  IBC_INI            Ephemeral local IBC config.
  IBC_TWS_VERSION    Override auto-detected TWS major version for IBC.
  IBC_TRADING_MODE   Override IBC TradingMode; defaults to ibc.ini.
USAGE
}

detect_tws_install() {
  if [ -n "${IBC_TWS_VERSION:-}" ]; then
    printf '/opt/tws\t%s\n' "$IBC_TWS_VERSION"
    return
  fi

  local version
  version=$(
    find "$TWS_DIR" -mindepth 2 -maxdepth 2 -type d -name jars -print 2>/dev/null \
    | sed 's#/jars$##' \
    | sed -n 's#.*/\([0-9][0-9]*\)$#\1#p' \
    | sort -rn \
    | head -n 1
  )

  if [ -n "$version" ]; then
    printf '/opt/tws\t%s\n' "$version"
    return
  fi

  if [ -d "$TWS_DIR/jars" ]; then
    printf '/opt\ttws\n'
  fi
}

restore_ibc_launchers() {
  if [ ! -e "$TWS_DIR/tws" ] && [ -e "$TWS_DIR/tws1" ]; then
    mv "$TWS_DIR/tws1" "$TWS_DIR/tws"
  fi
  if [ ! -e "$TWS_DIR/ibgateway" ] && [ -e "$TWS_DIR/ibgateway1" ]; then
    mv "$TWS_DIR/ibgateway1" "$TWS_DIR/ibgateway"
  fi
}

DISPLAY_MODE="${TWS_DISPLAY_MODE:-${TWS_MODE:-visible}}"
APP_MODE="${TWS_APP_MODE:-direct}"
if [ "$DISPLAY_MODE" = "ibc" ]; then
  DISPLAY_MODE="${TWS_DISPLAY_MODE:-visible}"
  APP_MODE="ibc"
fi
SCREENSHOT_ONLY=0
ARGS=()

while (($#)); do
  case "$1" in
    --visible)
      DISPLAY_MODE="visible"
      shift
      ;;
    --x11)
      DISPLAY_MODE="x11"
      shift
      ;;
    --xvfb)
      DISPLAY_MODE="xvfb"
      shift
      ;;
    --ibc)
      APP_MODE="ibc"
      shift
      ;;
    --screenshot-only)
      SCREENSHOT_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

if [ "$DISPLAY_MODE" = "xvfb" ]; then
  replay_args=(--x11)
  if [ "$APP_MODE" = "ibc" ]; then
    replay_args+=(--ibc)
  fi
  exec xvfb-run -a --server-args="-screen 0 ${TWS_XVFB_GEOMETRY:-1920x1080x24}" "$0" "${replay_args[@]}" "${ARGS[@]}"
fi

if [ "$APP_MODE" = "ibc" ]; then
  if [ -z "${IBC_INI:-}" ]; then
    echo "tws --ibc requires IBC_INI to point at an ephemeral local IBC config" >&2
    exit 2
  fi
  if [ -z "${IBC_DIR:-}" ] || [ ! -d "${IBC_DIR:-}" ]; then
    echo "tws --ibc requires IBC_DIR to point at a packaged IBC directory" >&2
    exit 2
  fi
fi

# Use MD5 of Dockerfile contents as a unique image name.
IMAGE_NAME="tws:$(md5sum "$DOCKERFILE" | cut -c1-8)"
TWS_DIR="${TWS_DIR:-$HOME/.local/opt/tws}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/tws}"
TWS_LOG_DIR="${TWS_LOG_DIR:-$HOME/.local/state/tws}"
USER_ID=$(id -u)
GROUP_ID=$(id -g)

mkdir -p "$TWS_DIR" "$CONFIG_DIR" "$TWS_LOG_DIR"

# Build image if it doesn't exist
if ! podman image exists "$IMAGE_NAME" 2>/dev/null; then
  echo "Building container image $IMAGE_NAME..."
  podman build -t "$IMAGE_NAME" -f "$DOCKERFILE" "$(dirname "$DOCKERFILE")"
fi

# Install TWS if the launcher is missing
if [ ! -f "$TWS_DIR/tws" ]; then
  echo "Installing TWS to $TWS_DIR..."
  I4J_TEMP=$(mktemp -d)
  chmod 777 "$I4J_TEMP"

  echo "Step 1: Running Installer..."
  podman run --rm \
    --userns=keep-id \
    -u "$USER_ID:$GROUP_ID" \
    -v "$TWS_DIR:/opt/tws" \
    -v "$I4J_TEMP:/opt/i4j_jres" \
    -e "HOME=/home/tws" \
    "$IMAGE_NAME" \
    bash -c "curl -L -o /tmp/tws-installer.sh https://download2.interactivebrokers.com/installers/tws/latest-standalone/tws-latest-standalone-linux-x64.sh && \
             chmod +x /tmp/tws-installer.sh && \
             INSTALL4J_KEEP_TEMP=true /tmp/tws-installer.sh -q -dir /opt/tws"
  
  echo "Installer finished with exit code $?. Proceeding to Step 2..."

  echo "Step 2: Relocating JRE and Fixing permissions..."
  podman run --rm \
    --userns=keep-id \
    -u "$USER_ID:$GROUP_ID" \
    -v "$TWS_DIR:/opt/tws" \
    -v "$I4J_TEMP:/opt/i4j_jres" \
    -e "HOME=/home/tws" \
    "$IMAGE_NAME" \
    bash -c "JRE_BIN=\$(find /opt/i4j_jres -maxdepth 3 -name bin -type d | head -n 1) ; \
             if [ -n \"\$JRE_BIN\" ]; then \
               JRE_DIR=\$(dirname \"\$JRE_BIN\") ; \
               echo \"Moving bundled JRE from \$JRE_DIR to /opt/tws/jre...\" ; \
               mkdir -p /opt/tws/jre ; \
               cp -r \"\$JRE_DIR\"/* /opt/tws/jre/ ; \
             fi ; \
             if [ -f /opt/tws/tws ]; then \
               sed -i 's/ver_minor -lt 16/ver_minor -lt 0/' /opt/tws/tws ; \
               sed -i 's/ver_micro -lt 16/ver_micro -lt 0/' /opt/tws/tws ; \
             fi ; \
             chown -R $USER_ID:$GROUP_ID /opt/tws"

  rm -rf "$I4J_TEMP"
fi

restore_ibc_launchers

if [ "$SCREENSHOT_ONLY" = "1" ]; then
  echo "TWS image/install check passed for $IMAGE_NAME"
  exit 0
fi

podman_args=(
  --rm
  --net=host \
  --userns=keep-id \
  --shm-size=2g \
  --device /dev/dri \
  -u "$USER_ID:$GROUP_ID" \
  -v "$TWS_DIR:/opt/tws" \
  -v "$CONFIG_DIR:/home/tws/Jts" \
  -v "$TWS_LOG_DIR:/home/tws/ibkr-logs" \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -e DISPLAY \
  -e "GDK_SCALE=2" \
  -e "HOME=/home/tws" \
  -e "INSTALL4J_NO_DB=true" \
  -e "JAVA_TOOL_OPTIONS=-Dsun.java2d.uiScale=2 -Duser.home=/home/tws" \
  -e "INSTALL4J_JAVA_HOME_OVERRIDE=/opt/tws/jre"
)

if [ "$DISPLAY_MODE" = "visible" ] && [ -n "${WAYLAND_DISPLAY:-}" ]; then
  WAYLAND_SOCKET_PATH="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
  podman_args+=(
    -v "$WAYLAND_SOCKET_PATH:$WAYLAND_SOCKET_PATH:ro"
    -e "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
    -e "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
    -e "GDK_BACKEND=wayland"
  )
else
  podman_args+=(-e "GDK_BACKEND=x11")
fi

if [ -n "${XAUTHORITY:-}" ] && [ -f "${XAUTHORITY:-}" ]; then
  podman_args+=(-v "$XAUTHORITY:$XAUTHORITY:ro" -e "XAUTHORITY=$XAUTHORITY")
fi

if [ -n "${IBC_INI:-}" ]; then
  podman_args+=(-v "$IBC_INI:/home/tws/ibc.ini:ro" -e "IBC_INI=/home/tws/ibc.ini")
fi

container_cmd=(/opt/tws/tws "${ARGS[@]}")

if [ "$APP_MODE" = "ibc" ]; then
  tws_install=$(detect_tws_install)
  if [ -z "$tws_install" ]; then
    echo "tws --ibc could not auto-detect an installed TWS layout under $TWS_DIR" >&2
    echo "Set IBC_TWS_VERSION, or launch TWS once without --ibc to complete installation." >&2
    exit 2
  fi
  ibc_tws_path=${tws_install%%$'\t'*}
  tws_major_version=${tws_install#*$'\t'}

  podman_args+=(
    -v "$IBC_DIR:/opt/ibc:ro"
    -e "IBC_VRSN=${IBC_VERSION:-unknown}"
  )

  container_cmd=(
    bash
    /opt/ibc/scripts/ibcstart.sh
    "$tws_major_version"
    --tws-path="$ibc_tws_path"
    --tws-settings-path=/home/tws/Jts
    --ibc-path=/opt/ibc
    --ibc-ini=/home/tws/ibc.ini
    --java-path=/opt/tws/jre/bin
    --on2fatimeout=exit
  )

  if [ -n "${IBC_TRADING_MODE:-}" ]; then
    container_cmd+=(--mode="$IBC_TRADING_MODE")
  fi
fi

# Execute TWS using its own JRE, or IBC with TWS jars and JRE.
if [ "$APP_MODE" = "ibc" ]; then
  trap restore_ibc_launchers EXIT
  podman run "${podman_args[@]}" "$IMAGE_NAME" "${container_cmd[@]}"
  exit $?
fi

exec podman run "${podman_args[@]}" "$IMAGE_NAME" "${container_cmd[@]}"
