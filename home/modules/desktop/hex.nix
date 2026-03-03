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
    home.activation.hexSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      settings_dir="$HOME/Library/Application Support/com.kitlangton.Hex"
      settings_file="$settings_dir/hex_settings.json"

      run mkdir -p "$settings_dir"

      if [ ! -f "$settings_file" ]; then
        run /usr/bin/plutil -create json "$settings_file"
      fi

      run /usr/bin/plutil -replace openOnLogin -bool ${boolToString cfg.openOnLogin} "$settings_file"
      run /usr/bin/plutil -replace showDockIcon -bool ${boolToString cfg.showDockIcon} "$settings_file"
    '';
  };
}
