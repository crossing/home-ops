{ channels
, ...
}:
self: super: {
  inherit (channels.nixpkgs-unstable) docker antigravity gemini-cli gws;
  inherit (channels.nixpkgs-old) mongodb-7_0;
}
