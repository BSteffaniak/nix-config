{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.desktop.hammerspoon;
in
{
  options.myConfig.desktop.hammerspoon = {
    enable = mkEnableOption "Hammerspoon macOS automation configuration";
  };

  config = mkIf cfg.enable {
    # Deploy Hammerspoon config to ~/.hammerspoon/init.lua
    # Hammerspoon uses ~/.hammerspoon/ (not XDG config)
    home.file.".hammerspoon/init.lua" = {
      source = ../../../configs/hammerspoon/init.lua;
      onChange = ''
        # Reload Hammerspoon config after nix rebuild deploys new file
        /Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -c "hs.reload()" || true
      '';
    };
  };
}
