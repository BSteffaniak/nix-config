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
    ./hammerspoon.nix
    ./homebrew.nix
    ./sketchybar.nix
    ./ssh.nix
    ./system-defaults.nix
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
