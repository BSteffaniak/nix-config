{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:

with lib;

let
  cfg = config.myConfig.cliTools.formatters;

  mkEnable = myLib.mkEnableOption' cfg.enableAll;
in
{
  options.myConfig.cliTools.formatters = {
    enableAll = mkOption {
      type = types.bool;
      default = false;
      description = "Enable all code formatters (can be overridden per-tool)";
    };

    nixfmt.enable = mkEnable "Nix formatter (nixfmt-rfc-style)";
    eslint.enable = mkEnable "ESLint daemon";
    prettier.enable = mkEnable "Prettier daemon";
    taplo.enable = mkEnable "TOML formatter";
  };

  config = {
    home.packages = mkMerge [
      (mkIf cfg.nixfmt.enable [ pkgs.nixfmt-rfc-style ])
      (mkIf cfg.eslint.enable [ pkgs.eslint_d ])
      (mkIf cfg.prettier.enable [ pkgs.prettierd ])
      (mkIf cfg.taplo.enable [ pkgs.taplo ])
    ];
  };
}
