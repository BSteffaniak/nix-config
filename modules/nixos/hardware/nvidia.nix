{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.myConfig.hardware.nvidia = {
    enable = lib.mkEnableOption "NVIDIA GPU support";
  };

  config = lib.mkIf config.myConfig.hardware.nvidia.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
      forceFullCompositionPipeline = true;
      powerManagement.enable = true;
    };

    environment.systemPackages = with pkgs; [
      nvidia-vaapi-driver
      libva-utils
    ];

    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "nvidia";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      WLR_NO_HARDWARE_CURSORS = "1";
    };
  };
}
