{ channels
, ...
}:
self: super: {
  inherit (channels.nixpkgs-unstable) docker;
  inherit (channels.nixpkgs-old) mongodb-7_0;
}
