{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.myConfig.system.networking = {
    enable = lib.mkEnableOption "Networking configuration";
    allowedTCPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [ ];
      description = "Additional TCP ports to open";
    };
    allowedUDPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [ ];
      description = "Additional UDP ports to open";
    };
  };

  config = lib.mkIf config.myConfig.system.networking.enable {
    networking = {
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
