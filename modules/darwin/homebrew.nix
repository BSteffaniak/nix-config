{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  options.myConfig.darwin.homebrew = {
    enable = mkEnableOption "Homebrew package manager";
  };

  config = mkIf config.myConfig.darwin.homebrew.enable {
    homebrew = {
      enable = true;
      onActivation.cleanup = "zap";
      onActivation.upgrade = true;
      casks = optionals config.myConfig.development.android.enable [ "android-studio" ];
    };
  };
}
