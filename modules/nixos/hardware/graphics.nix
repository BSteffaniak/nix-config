{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  options.myConfig.hardware.graphics = {
    enable = mkEnableOption "Graphics and OpenGL support";
  };

  config = mkIf config.myConfig.hardware.graphics.enable {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        libva-vdpau-driver
        libvdpau-va-gl
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];
    };
  };
}
