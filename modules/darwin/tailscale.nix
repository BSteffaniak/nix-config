{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.myConfig.services.tailscale.enable {
    homebrew.casks = [ "tailscale-app" ];
  };
}
