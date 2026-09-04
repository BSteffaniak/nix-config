{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.myConfig.darwin.security = {
    touchId.enable = lib.mkEnableOption "Touch ID for sudo authentication";
  };

  config = lib.mkIf config.myConfig.darwin.security.touchId.enable {
    security.pam.services.sudo_local.touchIdAuth = true;
  };
}
