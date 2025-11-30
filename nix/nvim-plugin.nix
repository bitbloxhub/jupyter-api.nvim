_:
{
  perSystem =
    {
      pkgs,
      self',
      ...
    }:
    {
      packages.jupyter-api-nvim = pkgs.vimUtils.buildVimPlugin {
        name = "jupyter-api.nvim";
        src = ../.;
        # Based on blink.cmp, https://github.com/saghen/blink.cmp/blob/f132267/flake.nix#L69
        preInstall = ''
          mkdir -p target/release
          ln -s ${self'.packages.jupyter-api-nvim-lib}/lib/libjupyter_api_nvim.* target/release/
        '';
      };
    };
}
