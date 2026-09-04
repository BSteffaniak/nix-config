{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:

let
  cfg = config.myConfig.cliTools.formatters;

  mkEnable = myLib.mkEnableOption' cfg.enableAll;
in
{
  options.myConfig.cliTools.formatters = {
    enableAll = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable all code formatters (can be overridden per-tool)";
    };

    nixfmt.enable = mkEnable "Nix formatter (nixfmt-rfc-style)";
    eslint.enable = mkEnable "ESLint daemon";
    prettier.enable = mkEnable "Prettier CLI + daemon";
    taplo.enable = mkEnable "TOML formatter";
  };

  config = {
    home.packages = lib.mkMerge [
      (lib.mkIf cfg.nixfmt.enable [ pkgs.nixfmt-rfc-style ])
      (lib.mkIf cfg.eslint.enable [ pkgs.eslint_d ])
      (lib.mkIf cfg.prettier.enable [
        pkgs.prettier
        pkgs.prettierd
      ])
      (lib.mkIf cfg.taplo.enable [ pkgs.taplo ])
    ];
  };
}
