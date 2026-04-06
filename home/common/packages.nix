{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages =
    with pkgs;
    [
      # Password management
      bitwarden-desktop

      # Development tools
      gh-dash
      natscli

      # Cloud tools
      flyctl

      # Media tools
      mediainfo
      flac

      # Code tools
      worktree-setup
      bmux
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      # Linux-only packages
      hyprshot
      brightnessctl
      libinput
      evtest
      qalculate-gtk
      kdePackages.elisa
    ];
}
