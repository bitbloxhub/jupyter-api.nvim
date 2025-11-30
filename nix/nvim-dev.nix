{
  inputs,
  ...
}:
{
  flake-file.inputs.nixcats.url = "github:BirdeeHub/nixCats-nvim";

  perSystem =
    {
      pkgs,
      self',
      ...
    }:
    let
      categoryDefinitions = _: {
        startupPlugins = {
          general = with pkgs.vimPlugins; [
            catppuccin-nvim
            neorepl-nvim
            self'.packages.jupyter-api-nvim
          ];
        };
      };
      packageDefinitions = {
        nvim-dev = _: {
          settings = {
            wrapRc = true;
            configDirName = "nvim-dev";
            suffix-path = false;
          };
          categories = {
            general = true;
          };
        };
      };
      packDir = builtins.head (
        builtins.match "^.*= '/nix/store/(.*-vim-pack-dir)'.*$" self'.packages.nvim-dev.setupLua
      );
    in
    {
      # For the devshell
      extra.packDir = "/nix/store/${packDir}";
      packages.nvim-dev = inputs.nixcats.utils.baseBuilder ../nvim-dev-config {
        inherit pkgs;
      } categoryDefinitions packageDefinitions "nvim-dev";
      make-shells.default = {
        packages = [
          self'.packages.nvim-dev
          pkgs.stylua
          pkgs.lua-language-server
        ];
      };
      treefmt.programs.stylua.enable = true;
    };
}
