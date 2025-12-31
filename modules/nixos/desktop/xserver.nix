{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  options.myConfig.desktop.xserver = {
    enable = mkEnableOption "X Server and display manager";
  };

  config = mkIf config.myConfig.desktop.xserver.enable {
    services.xserver = {
      enable = true;
      excludePackages = [ pkgs.xterm ];
      xkb = {
        layout = "us";
        variant = "";
      };
    };

    services.displayManager.gdm = {
      enable = true;
      wayland = true;
    };

    services.libinput.enable = true;
    services.dbus.enable = true;
  };
}
