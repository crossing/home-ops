# TWS Podman Package Implementation Plan

## Goal

Switch from native Nix package (buildFHSEnv) to Podman-based container for running Interactive Brokers Trader Workstation (TWS).

## Problem Statement

The current native Nix package using `buildFHSEnv` has issues:
- Complex to maintain (hardcoded paths, patches for JVM version checks)
- JavaFX modules not properly available on classpath
- Difficult to handle GUI library dependencies

## Critique

### Defense (Pros)
- **Portability:** Moving dependency management into a container image (Ubuntu) bypasses Nix-specific FHS environment complexities and native library linkage issues.
- **Maintainability:** Standardizes TWS's self-updating mechanism, eliminating the need to track or repackage specific versions in the Nix store.
- **Persistence:** Isolating data to `~/.local/tws` allows for persistent JRE and configuration, solving the "re-downloading JRE" problem of native installations.

### Critique (Cons & Risks)
- **Security:** Running an untrusted, self-updating binary inside a container is safer, but blindly running an installer as a user in a container requires careful permission handling (the `--user` flag is good, but file ownership on the host needs management).
- **Performance:** Potential overhead from Podman/Wayland integration; no explicit setup for hardware acceleration (GPU) if TWS requires it for charts.
- **Nix Integration:** The current plan's `build-podman.sh` runs *outside* of the Nix build process (`nix build` triggers a shell script instead of pure Nix builds). This is technically a violation of Nix's "pure" build philosophy.
- **Dependency Bloat:** The container images could grow large if not managed.

## Refined Design

To address the Nix integration concerns, the build process should ideally move toward a more declarative container definition if possible (e.g., using `pkgs.dockerTools`), though a shell-script-based builder is a practical compromise for dynamic installers. The security risk is mitigated by using explicit user IDs.

```
┌─────────────────────────────────────────────────────────────┐
│  Host System                                              │
│  ├── Podman                                              │
│  ├── Wayland Compositor (KDE/GNOME)                     │
│  └── ~/.local/tws/ (persistent data)                       │
└─────────────────────────────────────────────────────────────┘
                           │
                    --wayland-flag
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Container (tws:latest)                                    │
│  ├── Ubuntu 24.04                                         │
│  ├── X/GTK libraries                                     │
│  └── TWS (self-installing)                                │
│      └── Installs to /home/tws                              │
│          └── JRE cached in /home/tws/jre                     │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Plan

### Phase 1: Create Files

| File | Purpose |
|------|---------|
| `build-podman.sh` | Podman image build script |
| `default.nix` | Nix package definition |
| `tws.desktop` | Desktop entry (optional) |
| `tws.png` | Application icon |

### Phase 2: Cleanup

Remove the following (no longer needed):

| File/Directory | Reason |
|---------------|--------|
| `packages/tws/files/` | Was extracted TWS (was in Git LFS) |
| `packages/tws/update.sh` | Extraction script |
| `packages/tws/tws-stable-standalone-linux-x64.sh` | Self-extracting installer |
| `packages/tws/source.json` | Source metadata |
| `.gitattributes` entry for `packages/tws/files/**` | LFS no longer needed |

### Phase 3: Build & Test

```bash
# Build the package
nix build .#packages.x86_64-linux.tws

# Run (requires Wayland)
tws

# Or first-time build image
cd packages/tws && ./build-podman.sh
```

## File Specifications

### build-podman.sh

```bash
#!/bin/bash
set -e

IMAGE_NAME="tws:latest"

build_image() {
    echo "Building $IMAGE_NAME..."
    podman build -t "$IMAGE_NAME" --build-arg UBUNTU_VERSION=24.04 - <<EOF
FROM ubuntu:${UBUNTU_VERSION:-24.04}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    libx11-6 \
    libxrender1 \
    libxtst6 \
    libxi6 \
    libxext6 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libxfixes3 \
    libxcursor1 \
    libxinerama1 \
    libgl1 \
    libglib2-0 \
    libgtk-3-0 \
    libcairo2 \
    libgdk-pixbuf-2.0-0 \
    libpango-1.0-0 \
    libatk1.0-0 \
    libharfbuzz0 \
    fontconfig \
    fonts-dejavu-core \
    fonts-liberation \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# TWS self-updating installer
RUN curl -o /tmp/tws-installer.sh \
    https://download2.interactivebrokers.com/installers/tws/tws-latest-linux-x64.sh \
    && chmod +x /tmp/tws-installer.sh \
    && /tmp/tws-installer.sh -q -dir /home/tws \
    && rm -f /tmp/tws-installer.sh

CMD ["/home/tws/tws"]
EOF
}

# Build if not exists
if ! podman image exists "$IMAGE_NAME" 2>/dev/null; then
    build_image
else
    echo "Image $IMAGE_NAME already exists"
fi
```

### default.nix

```nix
{ pkgs, lib, ... }:

let
  scriptDir = ./.;
in

pkgs.symlinkJoin {
  name = "tws";

  paths = [
    (pkgs.writeScriptBin "tws" ''
      #!/bin/sh
      
      IMAGE_NAME="tws:latest"
      TWS_DIR="$HOME/.local/tws"
      SCRIPT_DIR="${scriptDir}"
      
      # Ensure TWS directory exists
      mkdir -p "$TWS_DIR"
      
      # Build image if not exists
      if ! podman image exists "$IMAGE_NAME" 2>/dev/null; then
        echo "Building $IMAGE_NAME..."
        cd "$SCRIPT_DIR"
        chmod +x ./build-podman.sh
        ./build-podman.sh
      fi
      
      # Get current user IDs
      USER_ID=$(id -u)
      GROUP_ID=$(id -g)
      
      # Run TWS
      exec podman run --rm -ti \
        --net=host \
        -v /tmp/.X11-unix:/tmp/.X11-unix \
        -e DISPLAY=$DISPLAY \
        -v "$TWS_DIR:/home/tws" \
        --user="$USER_ID:$GROUP_ID" \
        -e "GDK_SCALE=2" \
        -e "HOME=/home/tws" \
        -e "INSTALL4J_NO_DB=true" \
        "$IMAGE_NAME" \
        /home/tws/tws "$@"
    '')

    (pkgs.makeDesktopItem {
      name = "tws";
      desktopItemName = "tws.desktop";
      genericName = "Trading Platform";
      comment = "Interactive Brokers Trader Workstation";
      exec = "tws";
      icon = "${scriptDir}/tws.png";
      categories = "Finance;";
    })
  ];
}
```

## Usage Flow

### First Run
1. Wrapper checks if `tws:latest` image exists
2. If not, builds image ( installs Ubuntu + deps + runs TWS installer)
3. TWS installer runs → installs to `/home/tws` in container
4. TWS downloads JRE to `/home/tws/jre`
5. Data persists to `~/.local/tws` on host

### Subsequent Runs
1. Wrapper runs container with cached image
2. TWS uses `~/.local/tws` for data + JRE
3. Auto-check for updates on startup

## Environment Variables

| Variable | Value | Description |
|----------|-------|-------------|
| GDK_SCALE | 2 | HiDPI scaling |
| HOME | /home/tws | Container home |
| INSTALL4J_NO_DB | true | Skip version check |
| WAYLAND_DISPLAY | (inherited) | Wayland socket |

## Volume Mounts

| Host | Container | Description |
|------|-----------|-------------|
| ~/.local/tws | /home/tws | TWS data, logs, JRE |

## Notes

- Keyboard layout handled by host's Wayland compositor (inherited)
- Running as current user (`--user` flag)
- No root inside container
- No version tracking needed - TWS self-updates
- NOTE: Updated default.nix wrapper to include basic X11 forwarding as a fallback alongside standard execution.
