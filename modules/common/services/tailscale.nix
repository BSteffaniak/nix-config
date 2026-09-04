{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.myConfig.services.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN";

    useRoutingFeatures = lib.mkOption {
      type = lib.types.enum [
        "none"
        "client"
        "server"
        "both"
      ];
      default = "none";
      description = "Enable routing features (exit node, subnet routing)";
    };

    authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to file containing auth key for headless authentication";
    };

    acceptRoutes = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Accept subnet routes advertised by other nodes";
    };

    extraUpFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra flags to pass to 'tailscale up'";
    };

    trustInterface = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Trust the tailscale0 interface in the firewall (NixOS only)";
    };
  };
}
