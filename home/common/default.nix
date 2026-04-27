{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./git.nix
    ./fish.nix
    ./shell.nix
  ];

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;
}
