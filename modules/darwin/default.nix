{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./aerospace.nix
    ./applications.nix
    ./figma.nix
    ./ghostty.nix
    ./google-chrome.nix
    ./hammerspoon.nix
    ./homebrew.nix
    ./istat-menus.nix
    ./keepingyouawake.nix
    ./microsoft-edge.nix
    ./roon.nix
    ./scroll-reverser.nix
    ./security.nix
    ./signal.nix
    ./sketchybar.nix
    ./ssh.nix
    ./system-defaults.nix
    ./system-limits.nix
    ./tailscale.nix
  ];

  config = {
    # Enable experimental features
    nix = {
      package = pkgs.nix;
      settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
    };

    # Enable fish shell
    programs.fish.enable = true;
  };
}
