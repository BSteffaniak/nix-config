{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.myConfig.services.tailscale.enable {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = config.myConfig.services.tailscale.useRoutingFeatures;
      authKeyFile = config.myConfig.services.tailscale.authKeyFile;
      extraUpFlags =
        config.myConfig.services.tailscale.extraUpFlags
        ++ lib.optional config.myConfig.services.tailscale.acceptRoutes "--accept-routes";
    };

    networking.firewall.trustedInterfaces = lib.mkIf config.myConfig.services.tailscale.trustInterface [
      "tailscale0"
    ];
  };
}
