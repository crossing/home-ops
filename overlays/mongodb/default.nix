{ channels
, ...
}:
self: super: {
  inherit (channels.nixpkgs-old) mongodb-7_0;
}
