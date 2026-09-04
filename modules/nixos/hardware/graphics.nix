{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.myConfig.hardware.graphics = {
    enable = lib.mkEnableOption "Graphics and OpenGL support";
  };

  config = lib.mkIf config.myConfig.hardware.graphics.enable {
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
