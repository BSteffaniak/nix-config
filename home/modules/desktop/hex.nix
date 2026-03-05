{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.desktop.hex;
in
{
  options.myConfig.desktop.hex = {
    enable = mkEnableOption "Hex desktop app settings";

    openOnLogin = mkOption {
      type = types.bool;
      default = true;
      description = "Whether Hex should report Open on Login as enabled";
    };

    showDockIcon = mkOption {
      type = types.bool;
      default = false;
      description = "Whether Hex should show a Dock icon";
    };
  };

  config = mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
    home.file."Library/Application Support/com.kitlangton.Hex/hex_settings.json".text =
      builtins.toJSON
        {
          openOnLogin = cfg.openOnLogin;
          showDockIcon = cfg.showDockIcon;
        };
  };
}
