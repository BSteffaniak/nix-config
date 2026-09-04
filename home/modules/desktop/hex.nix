{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.desktop.hex;
in
{
  options.myConfig.desktop.hex = {
    enable = lib.mkEnableOption "Hex desktop app settings";

    openOnLogin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether Hex should report Open on Login as enabled";
    };

    showDockIcon = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether Hex should show a Dock icon";
    };
  };

  config = lib.mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
    home.file."Library/Application Support/com.kitlangton.Hex/hex_settings.json".text =
      builtins.toJSON
        {
          openOnLogin = cfg.openOnLogin;
          showDockIcon = cfg.showDockIcon;
        };
  };
}
