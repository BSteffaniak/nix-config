{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.myConfig.desktop.waybar = {
    enable = lib.mkEnableOption "Waybar status bar";
  };

  config = lib.mkIf config.myConfig.desktop.waybar.enable {
    programs.waybar = {
      enable = true;
      package = pkgs.waybar.overrideAttrs (oldAttrs: {
        mesonFlags = oldAttrs.mesonFlags ++ [ "-Dexperimental=true" ];
      });
    };
  };
}
