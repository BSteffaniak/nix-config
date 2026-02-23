{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  options.myConfig.services.avahi = {
    enable = mkEnableOption "Avahi mDNS/DNS-SD daemon for local network discovery";
  };

  config = mkIf config.myConfig.services.avahi.enable {
    services.avahi = {
      enable = true;

      # Enable mDNS resolution via NSS so .local hostnames resolve
      nssmdns4 = true;

      # Publish this machine's hostname and address on the local network
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };

      # Open UDP port 5353 in the firewall for mDNS
      openFirewall = true;
    };
  };
}
