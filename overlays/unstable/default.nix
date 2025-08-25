{ channels
, ...
}:
self: super: {
  inherit (channels.nixpkgs-unstable) docker;
}
