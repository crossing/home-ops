{ channels
, ...
}:
self: super: {
  inherit (channels.nixpkgs-26-05) docker gws unifi _1password-gui _1password-cli vscode;
  inherit (channels.nixpkgs-old) mongodb-7_0;
}
