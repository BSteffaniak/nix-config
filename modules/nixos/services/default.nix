{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  imports = [
    ./avahi.nix
    ./docker.nix
    ./minecraft.nix
    ./observability.nix
    ./tailscale.nix
  ];

  options.myConfig.services = {
    enable = lib.mkEnableOption "System services";
  };
}
