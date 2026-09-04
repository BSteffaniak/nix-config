{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.myConfig.system.security = {
    enable = lib.mkEnableOption "Security configuration";
  };

  config = lib.mkIf config.myConfig.system.security.enable {
    security = {
      pam.services.swaylock = {
        text = ''
          auth include login
        '';
      };
      rtkit.enable = true;
    };
  };
}
