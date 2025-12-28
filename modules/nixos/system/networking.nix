{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  options.myConfig.system.networking = {
    enable = mkEnableOption "Networking configuration";
    hostName = mkOption {
      type = types.str;
      default = "nixos";
      description = "System hostname";
    };
    allowedTCPPorts = mkOption {
      type = types.listOf types.int;
      default = [ ];
      description = "Additional TCP ports to open";
    };
    allowedUDPPorts = mkOption {
      type = types.listOf types.int;
      default = [ ];
      description = "Additional UDP ports to open";
    };
  };

  config = mkIf config.myConfig.system.networking.enable {
    networking = {
      hostName = config.myConfig.system.networking.hostName;
      networkmanager.enable = true;

      firewall = {
        enable = true;
        allowedTCPPorts = [
          3000
          3131
          3366
          8000
          8080
          8081
          8086
          8343
          8344
          5173
        ]
        ++ config.myConfig.system.networking.allowedTCPPorts;
        allowedUDPPorts = config.myConfig.system.networking.allowedUDPPorts;
      };
    };

    environment.systemPackages = with pkgs; [
      networkmanager
      networkmanagerapplet
      wirelesstools
    ];

    services.printing.enable = true;
  };
}
