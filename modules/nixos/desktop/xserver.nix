{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.myConfig.desktop.xserver = {
    enable = lib.mkEnableOption "X Server and display manager";
  };

  config = lib.mkIf config.myConfig.desktop.xserver.enable {
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
