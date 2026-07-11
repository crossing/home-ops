#!/usr/bin/env bash
set -euo pipefail

APP_ID="ibgateway"
APP_LABEL="IB Gateway"
APP_CLI_NAME="ibgateway"

home_default() {
  local value=$1
  case "$value" in
    /*)
      printf '%s\n' "$value"
      ;;
    *)
      printf '%s/%s\n' "$HOME" "$value"
      ;;
  esac
}

usage() {
  cat <<USAGE
Usage: $APP_CLI_NAME [--visible|--x11|--xvfb] [--ibc] [--screenshot-only] [$APP_ID args...]

Modes:
  --visible          Use the current desktop session. This is the default.
  --x11              Use the current X11 DISPLAY and force GDK_BACKEND=x11.
  --xvfb             Start a virtual X11 display with xvfb-run, then launch $APP_LABEL.
  --ibc              Start $APP_LABEL through IBC; requires external IBC config.
  --screenshot-only  Build/install check only; do not start $APP_LABEL.

Environment:
  IBKR_INSTALL_DIR   Persistent app install directory.
  IBKR_CONFIG_DIR    Persistent Jts config directory.
  IBKR_LOG_DIR       Host log directory mounted into the container.
  IBKR_DISPLAY_MODE  visible, x11, xvfb, or ibc.
  IBKR_APP_MODE      direct or ibc.
  IBKR_XVFB_GEOMETRY Xvfb geometry; defaults to 1920x1080x24.
  IBC_INI            Ephemeral local IBC config.
  IBC_APP_VERSION    Override auto-detected app major version for IBC.
  IBKR_TRADING_MODE  Override IBC TradingMode; defaults to ibc.ini.
USAGE

  cat <<'USAGE'
  IBGATEWAY_DIR            Gateway install directory alias.
  IBGATEWAY_CONFIG_DIR     Gateway Jts config directory alias.
  IBGATEWAY_LOG_DIR        Gateway log directory alias.
  IBGATEWAY_DISPLAY_MODE   Gateway display mode alias.
  IBGATEWAY_MODE           Gateway mode alias; "ibc" starts IBC.
  IBGATEWAY_APP_MODE       Gateway app mode alias.
  IBGATEWAY_XVFB_GEOMETRY  Gateway Xvfb geometry alias.
  IBC_GATEWAY_VERSION      Gateway IBC version override alias.
  IBC_GATEWAY_TRADING_MODE Gateway IBC trading mode alias.
USAGE
}

restore_ibc_launchers() {
  if [ ! -e "$INSTALL_DIR/ibgateway" ] && [ -e "$INSTALL_DIR/ibgateway1" ]; then
    mv "$INSTALL_DIR/ibgateway1" "$INSTALL_DIR/ibgateway"
  fi
}

patch_vmoptions_path() {
  local vmoptions="$INSTALL_DIR/$APP_ID.vmoptions"
  [ -f "$vmoptions" ] || return 0
  sed -i "s#^-DvmOptionsPath=.*#-DvmOptionsPath=/opt/ibgateway/latest/$APP_ID.vmoptions#" "$vmoptions"
}

sanitize_output() {
  sed -E \
    -e 's/(jxBrowserKey = )[[:alnum:]]+/\1***/g' \
    -e 's/(-DjxBrowserKey=)[^[:space:]]+/\1***/g' \
    -e 's/(IbLoginId[[:space:]]*=[[:space:]]*)[^[:space:]]+/\1***/g' \
    -e 's/(IbPassword[[:space:]]*=[[:space:]]*)[^[:space:]]+/\1***/g'
}

detect_versioned_install() {
  local host_root=$1 container_path=$2 version

  [ -d "$host_root" ] || return 1

  version=$(
    find "$host_root" -mindepth 2 -maxdepth 2 -type d -name jars -print 2>/dev/null \
    | sed 's#/jars$##' \
    | sed -n 's#.*/\([0-9][0-9]*\)$#\1#p' \
    | sort -rn \
    | head -n 1
  )

  [ -n "$version" ] || return 1
  printf '%s\t%s\n' "$container_path" "$version"
}

detect_ibc_install() {
  if [ -n "${IBC_VERSION_OVERRIDE:-}" ]; then
    printf '%s\t%s\n' "/opt" "$IBC_VERSION_OVERRIDE"
    return 0
  fi

  if detect_versioned_install "$INSTALL_DIR/ibgateway" "/opt"; then
    return 0
  fi
  if detect_versioned_install "$INSTALL_DIR" "/opt"; then
    return 0
  fi
  if [ -d "$INSTALL_DIR/jars" ]; then
    printf '%s\t%s\n' "/opt" "latest"
    return 0
  fi
  return 0
}

default_install_dir=$(home_default ".local/opt/ibgateway")
default_config_dir=$(home_default ".config/ibgateway")
default_log_dir=$(home_default ".local/state/ibgateway")

DISPLAY_MODE="${IBKR_DISPLAY_MODE:-${IBKR_MODE:-}}"
APP_MODE="${IBKR_APP_MODE:-direct}"
XVFB_GEOMETRY="${IBKR_XVFB_GEOMETRY:-1920x1080x24}"
IBC_VERSION_OVERRIDE="${IBC_APP_VERSION:-${IBKR_IBC_VERSION:-}}"
IBC_TRADING_MODE_VALUE="${IBKR_TRADING_MODE:-}"

INSTALL_DIR="${IBGATEWAY_DIR:-${IBKR_INSTALL_DIR:-$default_install_dir}}"
CONFIG_DIR="${IBGATEWAY_CONFIG_DIR:-${IBKR_CONFIG_DIR:-$default_config_dir}}"
LOG_DIR="${IBGATEWAY_LOG_DIR:-${IBKR_LOG_DIR:-$default_log_dir}}"
DISPLAY_MODE="${IBGATEWAY_DISPLAY_MODE:-${IBGATEWAY_MODE:-${DISPLAY_MODE:-visible}}}"
APP_MODE="${IBGATEWAY_APP_MODE:-$APP_MODE}"
XVFB_GEOMETRY="${IBGATEWAY_XVFB_GEOMETRY:-$XVFB_GEOMETRY}"
IBC_VERSION_OVERRIDE="${IBC_GATEWAY_VERSION:-$IBC_VERSION_OVERRIDE}"
IBC_TRADING_MODE_VALUE="${IBC_GATEWAY_TRADING_MODE:-$IBC_TRADING_MODE_VALUE}"

DISPLAY_MODE="${DISPLAY_MODE:-visible}"
APP_MODE="${APP_MODE:-direct}"

if [ "$DISPLAY_MODE" = "ibc" ]; then
  DISPLAY_MODE="visible"
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

case "$DISPLAY_MODE" in
  visible|x11|xvfb)
    ;;
  *)
    echo "$APP_CLI_NAME: unsupported display mode: $DISPLAY_MODE" >&2
    exit 2
    ;;
esac

case "$APP_MODE" in
  direct|ibc)
    ;;
  *)
    echo "$APP_CLI_NAME: unsupported app mode: $APP_MODE" >&2
    exit 2
    ;;
esac

if [ "$DISPLAY_MODE" = "xvfb" ]; then
  replay_args=(--x11)
  if [ "$APP_MODE" = "ibc" ]; then
    replay_args+=(--ibc)
  fi
  exec xvfb-run -a --server-args="-screen 0 $XVFB_GEOMETRY" "$0" "${replay_args[@]}" "${ARGS[@]}"
fi

if [ "$APP_MODE" = "ibc" ]; then
  if [ -z "${IBC_INI:-}" ]; then
    echo "$APP_CLI_NAME --ibc requires IBC_INI to point at an ephemeral local IBC config" >&2
    exit 2
  fi
  if [ -z "${IBC_DIR:-}" ] || [ ! -d "${IBC_DIR:-}" ]; then
    echo "$APP_CLI_NAME --ibc requires IBC_DIR to point at a packaged IBC directory" >&2
    exit 2
  fi
fi

DOCKERFILE="${DOCKERFILE:?DOCKERFILE is required}"
IBGATEWAY_INSTALL_URL="${IBGATEWAY_INSTALL_URL:?IBGATEWAY_INSTALL_URL is required}"

IMAGE_NAME="$APP_ID:$(md5sum "$DOCKERFILE" | cut -c1-8)"
USER_ID=$(id -u)
GROUP_ID=$(id -g)
install_marker_path="$INSTALL_DIR/ibgateway"

mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$LOG_DIR"
restore_ibc_launchers

if ! podman image exists "$IMAGE_NAME" 2>/dev/null; then
  echo "Building container image $IMAGE_NAME..."
  podman build -t "$IMAGE_NAME" -f "$DOCKERFILE" "$(dirname "$DOCKERFILE")"
fi

if [ ! -f "$install_marker_path" ]; then
  echo "Installing $APP_LABEL to $INSTALL_DIR..."
  I4J_TEMP=$(mktemp -d)
  chmod 777 "$I4J_TEMP"

  echo "Step 1: Running installer..."
  podman run --rm \
    --userns=keep-id \
    -u "$USER_ID:$GROUP_ID" \
    -v "$INSTALL_DIR:/opt/ibgateway/latest" \
    -v "$I4J_TEMP:/opt/i4j_jres" \
    -e "HOME=/home/ibgateway" \
    "$IMAGE_NAME" \
    bash -c "curl -L -o /tmp/$APP_ID-installer.sh '$IBGATEWAY_INSTALL_URL' && \
             chmod +x /tmp/$APP_ID-installer.sh && \
             INSTALL4J_KEEP_TEMP=true /tmp/$APP_ID-installer.sh -q -dir '/opt/ibgateway/latest'"

  echo "Installer finished. Proceeding to Step 2..."

  echo "Step 2: Relocating JRE and fixing permissions..."
  podman run --rm \
    --userns=keep-id \
    -u "$USER_ID:$GROUP_ID" \
    -v "$INSTALL_DIR:/opt/ibgateway/latest" \
    -v "$I4J_TEMP:/opt/i4j_jres" \
    -e "HOME=/home/ibgateway" \
    "$IMAGE_NAME" \
    bash -c "JRE_BIN=\$(find /opt/i4j_jres -maxdepth 3 -name bin -type d | head -n 1) ; \
             if [ -n \"\$JRE_BIN\" ]; then \
               JRE_DIR=\$(dirname \"\$JRE_BIN\") ; \
               echo \"Moving bundled JRE from \$JRE_DIR to /opt/ibgateway/latest/jre...\" ; \
               mkdir -p '/opt/ibgateway/latest/jre' ; \
               cp -r \"\$JRE_DIR\"/* '/opt/ibgateway/latest/jre/' ; \
             fi ; \
             if [ -f '/opt/ibgateway/latest/ibgateway' ]; then \
               sed -i 's/ver_minor -lt 16/ver_minor -lt 0/' '/opt/ibgateway/latest/ibgateway' ; \
               sed -i 's/ver_micro -lt 16/ver_micro -lt 0/' '/opt/ibgateway/latest/ibgateway' ; \
             fi ; \
             chown -R $USER_ID:$GROUP_ID '/opt/ibgateway/latest'"

  rm -rf "$I4J_TEMP"
fi

restore_ibc_launchers
patch_vmoptions_path

if [ "$SCREENSHOT_ONLY" = "1" ]; then
  echo "$APP_LABEL image/install check passed for $IMAGE_NAME"
  exit 0
fi

podman_args=(
  --rm
  --net=host
  --userns=keep-id
  --shm-size=2g
  -u "$USER_ID:$GROUP_ID"
  -v "$INSTALL_DIR:/opt/ibgateway/latest"
  -v "$CONFIG_DIR:/home/ibgateway/Jts"
  -v "$LOG_DIR:/home/ibgateway/ibkr-logs"
  -v /tmp/.X11-unix:/tmp/.X11-unix
  -e DISPLAY
  -e "GDK_SCALE=2"
  -e "HOME=/home/ibgateway"
  -e "INSTALL4J_NO_DB=true"
  -e "JAVA_TOOL_OPTIONS=-Dsun.java2d.uiScale=2 -Duser.home=/home/ibgateway"
  -e "INSTALL4J_JAVA_HOME_OVERRIDE=/opt/ibgateway/latest/jre"
)

if [ -e /dev/dri ]; then
  podman_args+=(--device /dev/dri)
fi

if [ "$DISPLAY_MODE" = "visible" ] && [ -n "${WAYLAND_DISPLAY:-}" ] && [ -n "${XDG_RUNTIME_DIR:-}" ]; then
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
  podman_args+=(-v "$IBC_INI:/home/ibgateway/ibc.ini:ro" -e "IBC_INI=/home/ibgateway/ibc.ini")
fi

container_cmd=("/opt/ibgateway/latest/ibgateway" "${ARGS[@]}")

if [ "$APP_MODE" = "ibc" ]; then
  ibc_install=$(detect_ibc_install)
  if [ -z "$ibc_install" ]; then
    echo "$APP_CLI_NAME --ibc could not auto-detect an installed $APP_LABEL layout under $INSTALL_DIR" >&2
    echo "Set IBC_APP_VERSION, or launch $APP_CLI_NAME once without --ibc to complete installation." >&2
    exit 2
  fi
  ibc_app_path=${ibc_install%%$'\t'*}
  app_major_version=${ibc_install#*$'\t'}

  podman_args+=(
    -v "$IBC_DIR:/opt/ibc:ro"
    -e "IBC_VRSN=${IBC_VERSION:-unknown}"
  )

  container_cmd=(
    bash
    /opt/ibc/scripts/ibcstart.sh
    "$app_major_version"
  )

  container_cmd+=(--gateway)

  container_cmd+=(
    --tws-path="$ibc_app_path"
    --tws-settings-path=/home/ibgateway/Jts
    --ibc-path=/opt/ibc
    --ibc-ini=/home/ibgateway/ibc.ini
    --java-path="/opt/ibgateway/latest/jre/bin"
    --on2fatimeout=exit
  )

  if [ -n "${IBC_TRADING_MODE_VALUE:-}" ]; then
    container_cmd+=(--mode="$IBC_TRADING_MODE_VALUE")
  fi
fi

if [ "$APP_MODE" = "ibc" ]; then
  trap restore_ibc_launchers EXIT
  set +e
  podman run "${podman_args[@]}" "$IMAGE_NAME" "${container_cmd[@]}" 2>&1 | sanitize_output
  status=${PIPESTATUS[0]}
  set -e
  exit "$status"
fi

exec podman run "${podman_args[@]}" "$IMAGE_NAME" "${container_cmd[@]}"
