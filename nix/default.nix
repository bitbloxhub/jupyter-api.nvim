{
  inputs,
  ...
}:
{

  imports = [
    inputs.flake-file.flakeModules.default
    inputs.flake-file.flakeModules.import-tree
    inputs.treefmt-nix.flakeModule
  ];

  systems = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];

  flake-file = {
    outputs = "inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./nix)";
    inputs = {
      flake-file.url = "github:vic/flake-file";
      flake-parts = {
        url = "github:hercules-ci/flake-parts";
        inputs.nixpkgs-lib.follows = "nixpkgs";
      };
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
      flint = {
        url = "github:NotAShelf/flint";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      treefmt-nix = {
        url = "github:numtide/treefmt-nix";
        inputs.nixpkgs.follows = "nixpkgs";
      };
    };
  };

  perSystem.treefmt =
    {
      pkgs,
      ...
    }:
    {
      projectRootFile = "flake.lock";
      programs.nixfmt = {
        enable = true;
        package = pkgs.nixfmt;
      };
      programs.deadnix.enable = true;
      programs.statix.enable = true;
    };
}
