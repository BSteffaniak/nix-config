{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./boot
    ./hardware
    ./desktop
    ./services
    ./system
  ];

  nix.package = pkgs.nix;
}
