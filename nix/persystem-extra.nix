{
  lib,
  flake-parts-lib,
  ...
}:
flake-parts-lib.mkTransposedPerSystemModule {
  name = "extra";
  option = lib.mkOption {
    type = lib.types.attrs;
    default = { };
    description = "extra persystem outputs";
  };
  file = ./persystem-extra.nix;
}
