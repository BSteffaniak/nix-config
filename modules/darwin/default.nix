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
    ./awake.nix
    ./figma.nix
    ./ghostty.nix
    ./google-chrome.nix
    ./hex.nix
    ./homebrew.nix
    ./istat-menus.nix
    ./keepingyouawake.nix
    ./lspmux.nix
    ./minecraft.nix
    ./microsoft-edge.nix
    ./ollama.nix
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

  };
}
