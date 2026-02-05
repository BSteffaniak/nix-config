{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  config = mkIf config.myConfig.services.tailscale.enable {
    homebrew.casks = [ "tailscale-app" ];
  };
}
