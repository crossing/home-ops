{ channels
, ...
}:
self: super: {
  inherit (channels.nixpkgs-unstable) docker gws;
  inherit (channels.nixpkgs-old) mongodb-7_0;
}
