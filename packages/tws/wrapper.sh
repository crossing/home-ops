#!/usr/bin/env bash
set +e
set +u

# Use MD5 of Dockerfile path as a unique image name (provided by Nix)
IMAGE_NAME="tws:$(echo "$DOCKERFILE" | md5sum | cut -c1-8)"
TWS_DIR="${TWS_DIR:-$HOME/.local/opt/tws}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/tws}"
USER_ID=$(id -u)

mkdir -p "$TWS_DIR" "$CONFIG_DIR"

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
    -v "$TWS_DIR:/opt/tws" \
    -v "$I4J_TEMP:/opt/i4j_jres" \
    -e "HOME=/home/tws" \
    "$IMAGE_NAME" \
    bash -c "JRE_DIR=\$(find /opt/i4j_jres -maxdepth 3 -name bin -type d | head -n 1 | xargs dirname) && \
             if [ -n \"\$JRE_DIR\" ]; then \
               echo \"Moving bundled JRE from \$JRE_DIR to /opt/tws/jre...\" ; \
               mkdir -p /opt/tws/jre ; \
               cp -r \"\$JRE_DIR\"/* /opt/tws/jre/ ; \
             fi ; \
             if [ -f /opt/tws/tws ]; then \
               sed -i 's/ver_minor -lt 16/ver_minor -lt 0/' /opt/tws/tws ; \
               sed -i 's/ver_micro -lt 16/ver_micro -lt 0/' /opt/tws/tws ; \
             fi ; \
             chown -R $USER_ID:$USER_ID /opt/tws"

  rm -rf "$I4J_TEMP"
fi

# Detect Wayland socket
if [ -n "$WAYLAND_DISPLAY" ]; then
  WAYLAND_SOCKET_PATH="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
else
  WAYLAND_SOCKET_PATH="/run/user/$USER_ID/wayland-0"
fi

# Execute TWS using its own JRE
exec podman run --rm \
  --net=host \
  --userns=keep-id \
  --shm-size=2g \
  --device /dev/dri \
  -u "$USER_ID" \
  -v "$TWS_DIR:/opt/tws" \
  -v "$CONFIG_DIR:/root/Jts" \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v "$WAYLAND_SOCKET_PATH:$WAYLAND_SOCKET_PATH:ro" \
  -v "$XAUTHORITY:$XAUTHORITY:ro" \
  -e DISPLAY \
  -e WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
  -e XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
  -e XAUTHORITY="$XAUTHORITY" \
  -e "GDK_BACKEND=wayland" \
  -e "GDK_SCALE=2" \
  -e "HOME=/home/tws" \
  -e "INSTALL4J_NO_DB=true" \
  -e "JAVA_TOOL_OPTIONS=-Dsun.java2d.uiScale=2 -Duser.home=/home/tws" \
  -e "INSTALL4J_JAVA_HOME_OVERRIDE=/opt/tws/jre" \
  "$IMAGE_NAME" \
  /opt/tws/tws "$@"
