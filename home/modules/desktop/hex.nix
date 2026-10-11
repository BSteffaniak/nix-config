{
  config,
  lib,
  pkgs,
  inputs,
  osConfig ? null,
  ...
}:

let
  cfg = config.myConfig.desktop.hex;
  linuxSupported = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  darwinSupported = pkgs.stdenv.isDarwin && osConfig != null;
in
{
  imports = [ inputs.hex.homeManagerModules.default ];

  options.myConfig.desktop.hex = {
    enable = lib.mkEnableOption "Hex local voice dictation (Linux beta or macOS Homebrew app)";

    openOnLogin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start Hex with the graphical session on Linux, or enable Open on Login on macOS";
    };

    showDockIcon = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether Hex should show a Dock icon on macOS";
    };

    settings = lib.mkOption {
      type = lib.types.nullOr (pkgs.formats.json { }).type;
      default = null;
      example = {
        dictation_hotkey = {
          control = false;
          alt = true;
          shift = false;
          super_key = false;
          key = "space";
        };
        double_tap_lock = false;
        paste_with_shift = false;
        sound_effect_volume = 0.5;
        transcription = {
          model = "parakeet_unified_en";
          language = "en";
          recognition_hints = "";
        };
      };
      description = ''
        Linux settings in Hex's native JSON schema. Null leaves UI-managed settings
        untouched. Otherwise activation writes a writable settings file, preserving
        Hex's ability to save via atomic rename; declared settings replace UI edits
        on the next activation. Restart Hex after changes. Do not include secrets:
        the generated settings are stored in the Nix store. macOS ignores this option.
      '';
    };

    systemdTarget = lib.mkOption {
      type = lib.types.str;
      default = "graphical-session.target";
      example = "hyprland-session.target";
      description = "Linux user target that owns the graphical session; its display environment must be imported before it starts";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && !linuxSupported && !darwinSupported) {
      warnings = [
        "Hex is not packaged for this platform: Linux requires x86_64-linux; macOS installation requires nix-darwin/Homebrew. Skipping Hex installation."
      ];
    })

    (lib.mkIf linuxSupported {
      programs.hex = {
        enable = cfg.enable;
        package = pkgs.hex;
        autostart = cfg.openOnLogin;
        systemdTarget = cfg.systemdTarget;
      };
    })

    (lib.mkIf (cfg.enable && linuxSupported && cfg.settings != null) {
      home.activation.hexSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        let
          settingsFile = (pkgs.formats.json { }).generate "hex-linux-settings.json" (
            {
              schema_version = 1;
              paste_with_shift = false;
            }
            // cfg.settings
          );
          directory = "${config.xdg.dataHome}/voice-control";
        in
        ''
          run ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg directory}
          if ! ${pkgs.diffutils}/bin/cmp -s ${settingsFile} ${lib.escapeShellArg "${directory}/linux-settings.json"}; then
            run ${pkgs.coreutils}/bin/install -m 600 ${settingsFile} ${lib.escapeShellArg "${directory}/linux-settings.json.nix-new"}
            run ${pkgs.coreutils}/bin/mv -f ${lib.escapeShellArg "${directory}/linux-settings.json.nix-new"} ${lib.escapeShellArg "${directory}/linux-settings.json"}
          fi
        ''
      );
    })

    (lib.mkIf (cfg.enable && darwinSupported) {
      home.file."Library/Application Support/com.kitlangton.Hex/hex_settings.json".text =
        builtins.toJSON
          {
            openOnLogin = cfg.openOnLogin;
            showDockIcon = cfg.showDockIcon;
          };
    })
  ];
}
