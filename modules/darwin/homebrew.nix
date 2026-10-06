{
  config,
  lib,
  ...
}:

let
  cfg = config.myConfig.darwin;
in
{
  options.myConfig.darwin.homebrew = {
    enable = lib.mkEnableOption "Homebrew package manager";
  };

  options.myConfig.darwin.androidStudio = {
    enable = lib.mkEnableOption "Android Studio via Homebrew";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.homebrew.enable {
      homebrew = {
        enable = true;
        # Homebrew 7 disables the --cleanup flag emitted by nix-darwin's cleanup option.
        onActivation.cleanup = "none";
        onActivation.extraFlags = [
          "--force-cleanup"
          "--zap"
        ];
        onActivation.upgrade = true;
      };
    })

    (lib.mkIf cfg.androidStudio.enable {
      homebrew.casks = [ "android-studio" ];
      myConfig.darwin.homebrew.enable = true;
    })
  ];
}
