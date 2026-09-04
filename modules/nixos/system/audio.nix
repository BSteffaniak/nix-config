{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.myConfig.system.audio = {
    enable = lib.mkEnableOption "Audio with PipeWire";
  };

  config = lib.mkIf config.myConfig.system.audio.enable {
    services.pulseaudio.enable = false;

    services.pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };

    environment.systemPackages = with pkgs; [
      pavucontrol
      libopus
    ];
  };
}
