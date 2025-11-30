# DO-NOT-EDIT. This file was auto-generated using github:vic/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./nix);

  inputs = {
    actions-nix = {
      inputs = {
        flake-parts.follows = "flake-parts";
        git-hooks.follows = "git-hooks";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:nialov/actions.nix";
    };
    crane.url = "github:ipetkov/crane";
    flake-file.url = "github:vic/flake-file";
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs";
      url = "github:hercules-ci/flake-parts";
    };
    flint = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:NotAShelf/flint";
    };
    git-hooks = {
      inputs = {
        flake-compat.follows = "";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:cachix/git-hooks.nix";
    };
    import-tree.url = "github:vic/import-tree";
    make-shell = {
      inputs.flake-compat.follows = "";
      url = "github:nicknovitski/make-shell";
    };
    nix-auto-ci = {
      inputs = {
        actions-nix.follows = "actions-nix";
        flake-parts.follows = "flake-parts";
        git-hooks.follows = "git-hooks";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:aigis-llm/nix-auto-ci";
    };
    nixcats.url = "github:BirdeeHub/nixCats-nvim";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };
  };

}
