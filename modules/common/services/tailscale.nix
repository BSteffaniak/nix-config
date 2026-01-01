{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  options.myConfig.services.tailscale = {
    enable = mkEnableOption "Tailscale VPN";

    useRoutingFeatures = mkOption {
      type = types.enum [
        "none"
        "client"
        "server"
        "both"
      ];
      default = "none";
      description = "Enable routing features (exit node, subnet routing)";
    };

    authKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing auth key for headless authentication";
    };

    acceptRoutes = mkOption {
      type = types.bool;
      default = false;
      description = "Accept subnet routes advertised by other nodes";
    };

    extraUpFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra flags to pass to 'tailscale up'";
    };

    trustInterface = mkOption {
      type = types.bool;
      default = true;
      description = "Trust the tailscale0 interface in the firewall (NixOS only)";
    };
  };
}
