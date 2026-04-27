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

      # Code tools
      worktree-setup
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
