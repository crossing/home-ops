{ channels
, ...
}:
self: super: {
  inherit (channels.nixpkgs-unstable) docker antigravity;
  inherit (channels.nixpkgs-old) mongodb-7_0;
}
