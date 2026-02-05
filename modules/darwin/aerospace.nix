{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.desktop.aerospace;
in
{
  options.myConfig.desktop.aerospace = {
    enable = mkEnableOption "AeroSpace tiling window manager for macOS";
  };

  config = mkIf cfg.enable {
    # Install AeroSpace via homebrew cask
    # Note: The tap is declared in flake.nix (nix-homebrew.taps)
    homebrew.casks = [
      "aerospace"
    ];

    # Ensure homebrew is enabled when aerospace is enabled
    myConfig.darwin.homebrew.enable = true;
  };
}
