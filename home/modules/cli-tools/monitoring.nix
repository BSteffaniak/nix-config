{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:

with lib;

let
  cfg = config.myConfig.cliTools.monitoring;

  mkEnable = myLib.mkEnableOption' cfg.enableAll;
in
{
  options.myConfig.cliTools.monitoring = {
    enableAll = mkOption {
      type = types.bool;
      default = false;
      description = "Enable all monitoring tools (can be overridden per-tool)";
    };

    bottom.enable = mkEnable "Bottom system monitor";
    htop.enable = mkEnable "Htop system monitor";
    ncdu.enable = mkEnable "NCurses Disk Usage analyzer";
    bandwhich.enable = mkEnable "Bandwhich network bandwidth monitor";
    nethogs.enable = mkEnable "Nethogs network traffic monitor per process";
  };

  config = {
    # Bottom
    programs.bottom.enable = cfg.bottom.enable;
    xdg.configFile."bottom/bottom.toml" = mkIf cfg.bottom.enable {
      source = ../../../configs/bottom/bottom.toml;
    };

    # Htop
    home.packages = mkMerge [
      (mkIf cfg.htop.enable [ pkgs.htop ])
      (mkIf cfg.ncdu.enable [ pkgs.ncdu ])
      (mkIf cfg.bandwhich.enable [ pkgs.bandwhich ])
      (mkIf cfg.nethogs.enable [ pkgs.nethogs ])
    ];
    xdg.configFile."htop/htoprc" = mkIf cfg.htop.enable {
      source = ../../../configs/htop/htoprc;
    };
  };
}
