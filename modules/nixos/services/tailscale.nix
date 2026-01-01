{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  config = mkIf config.myConfig.services.tailscale.enable {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = config.myConfig.services.tailscale.useRoutingFeatures;
      authKeyFile = config.myConfig.services.tailscale.authKeyFile;
      extraUpFlags =
        config.myConfig.services.tailscale.extraUpFlags
        ++ optional config.myConfig.services.tailscale.acceptRoutes "--accept-routes";
    };

    networking.firewall.trustedInterfaces = mkIf config.myConfig.services.tailscale.trustInterface [
      "tailscale0"
    ];
  };
}
