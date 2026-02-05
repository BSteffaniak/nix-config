{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  options.myConfig.darwin.hammerspoon = {
    enable = mkEnableOption "Hammerspoon macOS automation";
  };

  config = mkIf config.myConfig.darwin.hammerspoon.enable {
    # Install via Homebrew cask
    homebrew.casks = [ "hammerspoon" ];

    # Ensure homebrew is enabled when hammerspoon is enabled
    myConfig.darwin.homebrew.enable = true;
  };
}
