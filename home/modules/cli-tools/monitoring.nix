{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:

let
  cfg = config.myConfig.cliTools.monitoring;

  mkEnable = myLib.mkEnableOption' cfg.enableAll;
in
{
  options.myConfig.cliTools.monitoring = {
    enableAll = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable all monitoring tools (can be overridden per-tool)";
    };

    bottom.enable = mkEnable "Bottom system monitor";
    htop.enable = mkEnable "Htop system monitor";
    ncdu.enable = mkEnable "NCurses Disk Usage analyzer";
    bandwhich.enable = mkEnable "Bandwhich network bandwidth monitor";
    nethogs.enable = myLib.mkEnableOption' (
      cfg.enableAll && pkgs.stdenv.isLinux
    ) "Nethogs network traffic monitor per process (Linux only)";
  };

  config = {
    # Bottom
    programs.bottom.enable = cfg.bottom.enable;
    xdg.configFile."bottom/bottom.toml" = lib.mkIf cfg.bottom.enable {
      source = ../../../configs/bottom/bottom.toml;
    };

    # Htop
    home.packages = lib.mkMerge [
      (lib.mkIf cfg.htop.enable [ pkgs.htop ])
      (lib.mkIf cfg.ncdu.enable [ pkgs.ncdu ])
      (lib.mkIf cfg.bandwhich.enable [ pkgs.bandwhich ])
      (lib.mkIf cfg.nethogs.enable [ pkgs.nethogs ])
    ];
    xdg.configFile."htop/htoprc" = lib.mkIf cfg.htop.enable {
      source = ../../../configs/htop/htoprc;
    };
  };
}
