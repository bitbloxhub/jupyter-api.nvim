{
  inputs,
  ...
}:
{
  flake-file.inputs.crane.url = "github:ipetkov/crane";

  perSystem =
    {
      pkgs,
      ...
    }:
    let
      craneLib = inputs.crane.mkLib pkgs;
      commonArgs = {
        src = craneLib.cleanCargoSource ../.;
        strictDeps = true;
      };
      jupyter-api-nvim = craneLib.buildPackage (
        commonArgs
        // {
          cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        }
      );
    in
    {
      packages.jupyter-api-nvim-lib = jupyter-api-nvim;
      make-shells.default = {
        packages = [
          pkgs.cargo
          pkgs.rustc
          pkgs.rustfmt
          pkgs.clippy
          pkgs.rust-analyzer
        ];
      };
      treefmt.programs.rustfmt.enable = true;
    };
}
