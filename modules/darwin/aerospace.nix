{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.desktop.aerospace;
in
{
  options.myConfig.desktop.aerospace = {
    enable = lib.mkEnableOption "AeroSpace tiling window manager for macOS";
  };

  config = lib.mkIf cfg.enable {
    # Bundle cleanup resets trust to the Brewfile declarations. Keep item-specific
    # trust here rather than granting it in a pre-activation command.
    # The pinned nix-darwin cask options do not yet expose `trusted`.
    homebrew.extraConfig = ''
      cask "nikitabobko/tap/aerospace", trusted: true
    '';

    # Ensure homebrew is enabled when aerospace is enabled
    myConfig.darwin.homebrew.enable = true;
  };
}
