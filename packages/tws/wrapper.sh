#!/usr/bin/env bash
set -euo pipefail

APP_ID="${IBKR_APP_ID:-tws}"
APP_LABEL="${IBKR_APP_LABEL:-TWS}"
APP_CLI_NAME="${IBKR_APP_CLI_NAME:-$APP_ID}"

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

  case "$APP_ID" in
    tws)
      cat <<'USAGE'
  TWS_DIR            TWS install directory alias.
  CONFIG_DIR         TWS Jts config directory alias.
  TWS_LOG_DIR        TWS log directory alias.
  TWS_DISPLAY_MODE   TWS display mode alias.
  TWS_MODE           TWS mode alias; "ibc" starts IBC.
  TWS_APP_MODE       TWS app mode alias.
  TWS_XVFB_GEOMETRY  TWS Xvfb geometry alias.
  IBC_TWS_VERSION    TWS IBC version override alias.
  IBC_TRADING_MODE   TWS IBC trading mode alias.
USAGE
      ;;
    ibgateway)
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
      ;;
  esac
}

restore_ibc_launchers() {
  local rel backup
  for rel in ${IBKR_RESTORE_LAUNCHERS:-}; do
    backup="${rel}1"
    if [ ! -e "$INSTALL_DIR/$rel" ] && [ -e "$INSTALL_DIR/$backup" ]; then
      mv "$INSTALL_DIR/$backup" "$INSTALL_DIR/$rel"
    fi
  done
}

patch_vmoptions_path() {
  local vmoptions="$INSTALL_DIR/$APP_ID.vmoptions"
  [ -f "$vmoptions" ] || return 0
  sed -i "s#^-DvmOptionsPath=.*#-DvmOptionsPath=$IBKR_CONTAINER_INSTALL_ROOT/$APP_ID.vmoptions#" "$vmoptions"
}

sanitize_output() {
  sed -E \
    -e 's/(jxBrowserKey = )[[:alnum:]]+/\1***/g' \
    -e 's/(-DjxBrowserKey=)[^[:space:]]+/\1***/g'
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
    printf '%s\t%s\n' "$IBKR_IBC_VERSION_PATH" "$IBC_VERSION_OVERRIDE"
    return 0
  fi

  case "$IBKR_IBC_LAYOUT" in
    tws)
      if detect_versioned_install "$INSTALL_DIR" "$IBKR_IBC_VERSION_PATH"; then
        return 0
      fi

      if [ -d "$INSTALL_DIR/jars" ]; then
        printf '/opt\ttws\n'
        return 0
      fi
      ;;
    ibgateway)
      if detect_versioned_install "$INSTALL_DIR/ibgateway" "$IBKR_IBC_VERSION_PATH"; then
        return 0
      fi
      if detect_versioned_install "$INSTALL_DIR" "$IBKR_IBC_VERSION_PATH"; then
        return 0
      fi
      if [ -d "$INSTALL_DIR/jars" ]; then
        printf '%s\t%s\n' "$IBKR_IBC_VERSION_PATH" "$(basename "$IBKR_CONTAINER_INSTALL_ROOT")"
        return 0
      fi
      ;;
    *)
      echo "$APP_CLI_NAME: unsupported IBC layout: $IBKR_IBC_LAYOUT" >&2
      exit 2
      ;;
  esac

  return 0
}

default_install_dir=$(home_default "${IBKR_DEFAULT_INSTALL_DIR:-.local/opt/$APP_ID}")
default_config_dir=$(home_default "${IBKR_DEFAULT_CONFIG_DIR:-.config/$APP_ID}")
default_log_dir=$(home_default "${IBKR_DEFAULT_LOG_DIR:-.local/state/$APP_ID}")

DISPLAY_MODE="${IBKR_DISPLAY_MODE:-${IBKR_MODE:-}}"
APP_MODE="${IBKR_APP_MODE:-direct}"
XVFB_GEOMETRY="${IBKR_XVFB_GEOMETRY:-1920x1080x24}"
IBC_VERSION_OVERRIDE="${IBC_APP_VERSION:-${IBKR_IBC_VERSION:-}}"
IBC_TRADING_MODE_VALUE="${IBKR_TRADING_MODE:-}"

case "$APP_ID" in
  tws)
    INSTALL_DIR="${TWS_DIR:-${IBKR_INSTALL_DIR:-$default_install_dir}}"
    CONFIG_DIR="${CONFIG_DIR:-${TWS_CONFIG_DIR:-${IBKR_CONFIG_DIR:-$default_config_dir}}}"
    LOG_DIR="${TWS_LOG_DIR:-${IBKR_LOG_DIR:-$default_log_dir}}"
    DISPLAY_MODE="${TWS_DISPLAY_MODE:-${TWS_MODE:-${DISPLAY_MODE:-visible}}}"
    APP_MODE="${TWS_APP_MODE:-$APP_MODE}"
    XVFB_GEOMETRY="${TWS_XVFB_GEOMETRY:-$XVFB_GEOMETRY}"
    IBC_VERSION_OVERRIDE="${IBC_TWS_VERSION:-$IBC_VERSION_OVERRIDE}"
    IBC_TRADING_MODE_VALUE="${IBC_TRADING_MODE:-$IBC_TRADING_MODE_VALUE}"
    ;;
  ibgateway)
    INSTALL_DIR="${IBGATEWAY_DIR:-${IBKR_INSTALL_DIR:-$default_install_dir}}"
    CONFIG_DIR="${IBGATEWAY_CONFIG_DIR:-${IBKR_CONFIG_DIR:-$default_config_dir}}"
    LOG_DIR="${IBGATEWAY_LOG_DIR:-${IBKR_LOG_DIR:-$default_log_dir}}"
    DISPLAY_MODE="${IBGATEWAY_DISPLAY_MODE:-${IBGATEWAY_MODE:-${DISPLAY_MODE:-visible}}}"
    APP_MODE="${IBGATEWAY_APP_MODE:-$APP_MODE}"
    XVFB_GEOMETRY="${IBGATEWAY_XVFB_GEOMETRY:-$XVFB_GEOMETRY}"
    IBC_VERSION_OVERRIDE="${IBC_GATEWAY_VERSION:-$IBC_VERSION_OVERRIDE}"
    IBC_TRADING_MODE_VALUE="${IBC_GATEWAY_TRADING_MODE:-$IBC_TRADING_MODE_VALUE}"
    ;;
  *)
    INSTALL_DIR="${IBKR_INSTALL_DIR:-$default_install_dir}"
    CONFIG_DIR="${IBKR_CONFIG_DIR:-$default_config_dir}"
    LOG_DIR="${IBKR_LOG_DIR:-$default_log_dir}"
    DISPLAY_MODE="${DISPLAY_MODE:-visible}"
    ;;
esac

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
IBKR_INSTALL_URL="${IBKR_INSTALL_URL:?IBKR_INSTALL_URL is required}"
IBKR_CONTAINER_INSTALL_ROOT="${IBKR_CONTAINER_INSTALL_ROOT:?IBKR_CONTAINER_INSTALL_ROOT is required}"
IBKR_CONTAINER_APP_HOME="${IBKR_CONTAINER_APP_HOME:?IBKR_CONTAINER_APP_HOME is required}"
IBKR_APP_LAUNCHER="${IBKR_APP_LAUNCHER:?IBKR_APP_LAUNCHER is required}"
IBKR_INSTALL_MARKER="${IBKR_INSTALL_MARKER:?IBKR_INSTALL_MARKER is required}"
IBKR_IBC_LAYOUT="${IBKR_IBC_LAYOUT:?IBKR_IBC_LAYOUT is required}"
IBKR_IBC_VERSION_PATH="${IBKR_IBC_VERSION_PATH:?IBKR_IBC_VERSION_PATH is required}"

IMAGE_NAME="$APP_ID:$(md5sum "$DOCKERFILE" | cut -c1-8)"
USER_ID=$(id -u)
GROUP_ID=$(id -g)
install_marker_path="$INSTALL_DIR/$IBKR_INSTALL_MARKER"

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
    -v "$INSTALL_DIR:$IBKR_CONTAINER_INSTALL_ROOT" \
    -v "$I4J_TEMP:/opt/i4j_jres" \
    -e "HOME=/home/tws" \
    "$IMAGE_NAME" \
    bash -c "curl -L -o /tmp/$APP_ID-installer.sh '$IBKR_INSTALL_URL' && \
             chmod +x /tmp/$APP_ID-installer.sh && \
             INSTALL4J_KEEP_TEMP=true /tmp/$APP_ID-installer.sh -q -dir '$IBKR_CONTAINER_INSTALL_ROOT'"

  echo "Installer finished. Proceeding to Step 2..."

  echo "Step 2: Relocating JRE and fixing permissions..."
  podman run --rm \
    --userns=keep-id \
    -u "$USER_ID:$GROUP_ID" \
    -v "$INSTALL_DIR:$IBKR_CONTAINER_INSTALL_ROOT" \
    -v "$I4J_TEMP:/opt/i4j_jres" \
    -e "HOME=/home/tws" \
    "$IMAGE_NAME" \
    bash -c "JRE_BIN=\$(find /opt/i4j_jres -maxdepth 3 -name bin -type d | head -n 1) ; \
             if [ -n \"\$JRE_BIN\" ]; then \
               JRE_DIR=\$(dirname \"\$JRE_BIN\") ; \
               echo \"Moving bundled JRE from \$JRE_DIR to $IBKR_CONTAINER_APP_HOME/jre...\" ; \
               mkdir -p '$IBKR_CONTAINER_APP_HOME/jre' ; \
               cp -r \"\$JRE_DIR\"/* '$IBKR_CONTAINER_APP_HOME/jre/' ; \
             fi ; \
             if [ -f '$IBKR_APP_LAUNCHER' ]; then \
               sed -i 's/ver_minor -lt 16/ver_minor -lt 0/' '$IBKR_APP_LAUNCHER' ; \
               sed -i 's/ver_micro -lt 16/ver_micro -lt 0/' '$IBKR_APP_LAUNCHER' ; \
             fi ; \
             chown -R $USER_ID:$GROUP_ID '$IBKR_CONTAINER_INSTALL_ROOT'"

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
  -v "$INSTALL_DIR:$IBKR_CONTAINER_INSTALL_ROOT"
  -v "$CONFIG_DIR:/home/tws/Jts"
  -v "$LOG_DIR:/home/tws/ibkr-logs"
  -v /tmp/.X11-unix:/tmp/.X11-unix
  -e DISPLAY
  -e "GDK_SCALE=2"
  -e "HOME=/home/tws"
  -e "INSTALL4J_NO_DB=true"
  -e "JAVA_TOOL_OPTIONS=-Dsun.java2d.uiScale=2 -Duser.home=/home/tws"
  -e "INSTALL4J_JAVA_HOME_OVERRIDE=$IBKR_CONTAINER_APP_HOME/jre"
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
  podman_args+=(-v "$IBC_INI:/home/tws/ibc.ini:ro" -e "IBC_INI=/home/tws/ibc.ini")
fi

container_cmd=("$IBKR_APP_LAUNCHER" "${ARGS[@]}")

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

  if [ "${IBKR_IS_GATEWAY:-0}" = "1" ]; then
    container_cmd+=(--gateway)
  fi

  container_cmd+=(
    --tws-path="$ibc_app_path"
    --tws-settings-path=/home/tws/Jts
    --ibc-path=/opt/ibc
    --ibc-ini=/home/tws/ibc.ini
    --java-path="$IBKR_CONTAINER_APP_HOME/jre/bin"
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
