{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  options.myConfig.darwin.security = {
    touchId.enable = mkEnableOption "Touch ID for sudo authentication";
  };

  config = mkIf config.myConfig.darwin.security.touchId.enable {
    security.pam.services.sudo_local.touchIdAuth = true;
  };
}
