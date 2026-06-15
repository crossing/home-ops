{
  inputs,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  inherit (inputs.llm-agents.packages.${system}) hermes-desktop hermes-agent;
in
hermes-desktop.overrideAttrs (oldAttrs: {
  postPatch = (oldAttrs.postPatch or "") + ''
    # Normalize line endings to avoid pattern matching failures due to CRLF
    sed -i 's/\r//g' src/main/installer.ts

    # Extract the environment variables from the hermes-agent wrapper script
    agent_bin="${hermes-agent}/bin/hermes"
    python_env_bin=$(sed -n "s/export HERMES_PYTHON='\(.*\)'/\1/p" $agent_bin)
    hermes_wrapped=$(sed -n 's/exec -a "\$0" "\(.*\)"[ ]*"\$@"/ \1/p' $agent_bin | tr -d ' ')
    tui_dir=$(sed -n "s/export HERMES_TUI_DIR='\(.*\)'/\1/p" $agent_bin)
    web_dist=$(sed -n "s/export HERMES_WEB_DIST='\(.*\)'/\1/p" $agent_bin)
    src_root=$(sed -n "s/export HERMES_PYTHON_SRC_ROOT='\(.*\)'/\1/p" $agent_bin)
    node_bin=$(sed -n "s/export HERMES_NODE='\(.*\)'/\1/p" $agent_bin)

    # Create a python wrapper script for hermes-desktop to execute
    cat <<EOF > src/main/hermes-python-wrapper
#!/bin/sh
export PYTHONNOUSERSITE='true'
export HERMES_TUI_DIR='$tui_dir'
export HERMES_WEB_DIST='$web_dist'
export HERMES_PYTHON='$python_env_bin'
export HERMES_PYTHON_SRC_ROOT='$src_root'
export HERMES_NODE='$node_bin'
exec '$python_env_bin' "\$@"
EOF
    chmod +x src/main/hermes-python-wrapper

    # Patch src/main/installer.ts to use our custom paths
    substituteInPlace src/main/installer.ts \
      --replace-fail 'export const HERMES_REPO = join(HERMES_HOME, "hermes-agent");' "export const HERMES_REPO = \"${hermes-agent}\";" \
      --replace-fail 'export const HERMES_PYTHON = IS_WINDOWS' "export const HERMES_PYTHON = \"$out/libexec/hermes-python-wrapper\"; const _dummy_python = IS_WINDOWS" \
      --replace-fail 'export const HERMES_SCRIPT = IS_WINDOWS' "export const HERMES_SCRIPT = \"$hermes_wrapped\"; const _dummy_script = IS_WINDOWS"
  '';

  postInstall = (oldAttrs.postInstall or "") + ''
    # Install our python wrapper script
    mkdir -p $out/libexec
    cp src/main/hermes-python-wrapper $out/libexec/hermes-python-wrapper
  '';
})
