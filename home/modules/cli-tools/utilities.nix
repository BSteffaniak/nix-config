{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:

with lib;

let
  cfg = config.myConfig.cliTools.utilities;

  mkEnable = myLib.mkEnableOption' cfg.enableAll;
  mkMediaEnable = myLib.mkEnableOption' cfg.media.enableAll;

  # Convert declarativeBindings value (nice form or raw TOML) into TOML text
  bindingsFragmentToToml =
    name: value:
    if builtins.isString value then
      value
    else
      lib.concatLines (
        lib.mapAttrsToList (
          profile: commands:
          lib.concatLines (
            map (cmd: ''
              [[binding]]
              profile = "${profile}"
              command = "${cmd}"
            '') commands
          )
        ) value
      );

  # Base bindings automatically provided when sshenv + autoBindings are enabled.
  # Pi entries are intentionally NOT bound here — pi resolves its own auth via
  # the sshenv-auth extension at ~/.config/nix/configs/pi/extensions/sshenv-auth/,
  # configured per-profile by ~/.config/nix/configs/pi/providers/*.json. Keeping
  # pi-* shims here would shadow the provider wrappers from pi.nix.
  autoSshenvBindings = {
    "00-sshenv-auto" = {
      openai-api = [
        "opencode-openai-api"
      ];
      openrouter = [
        "opencode-openrouter"
      ];
      opencode-zen = [
        "opencode-zen"
      ];
      xai = [
        "opencode-grok-4-3"
        "opencode-grok-code-fast"
      ];
    };
  };
in
{
  options.myConfig.cliTools.utilities = {
    enableAll = mkOption {
      type = types.bool;
      default = false;
      description = "Enable all utility tools (can be overridden per-tool)";
    };

    direnv = {
      enable = mkEnable "Direnv for per-directory environments";
      nix-direnv = mkOption {
        type = types.bool;
        default = true;
        description = "Enable nix-direnv integration";
      };
    };

    jq.enable = mkEnable "JSON processor";
    parallel.enable = mkEnable "GNU parallel";
    write-good.enable = mkEnable "writing quality checker";
    cronstrue.enable = mkEnable "cron expression diagnostic tool";
    clippier.enable = mkEnable "Clippier CI helper";
    cloc.enable = mkEnable "lines of code counter";
    watchexec.enable = mkEnable "file watcher/executor";
    lsof.enable = mkEnable "list open files utility";
    killall.enable = mkEnable "killall utility";
    nix-search.enable = mkEnable "Nix package search";

    media = {
      enableAll = mkOption {
        type = types.bool;
        default = cfg.enableAll;
        description = "Enable all media tools (can be overridden per-tool)";
      };

      ffmpeg.enable = mkMediaEnable "FFmpeg media processor";
      flac.enable = mkMediaEnable "FLAC codec";
      mediainfo.enable = mkMediaEnable "media info analyzer";
    };

    opencodeUpstream.enable = mkEnable "upstream OpenCode CLI";
    pi.enable = mkEnable "Pi coding agent CLI without managed config";
    sshenv = {
      enable = mkEnable "sshenv SSH-key-backed env vault";

      autoBindings = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Automatically provide useful bindings for pi-* commands (and common opencode aliases)
          when sshenv is enabled. Set to false to fully control bindings yourself.
        '';
      };

      declarativeBindings = mkOption {
        type = types.attrsOf (
          types.oneOf [
            (types.attrsOf (types.listOf types.str)) # nice form: profile -> [commands]
            types.lines # raw TOML escape hatch
          ]
        );
        default = { };
        example = {
          "10-core" = {
            openrouter = [
              "pi-openrouter"
              "opencode-openrouter"
            ];
            xai = [
              "pi-grok-4.3"
              "pi-grok-code-fast"
            ];
          };
        };
        description = ''
          Declarative bindings written to ~/.sshenv/bindings.d/<name>.toml.
          Supports two forms:
            - Nice form: { profile = [ "cmd1" "cmd2" ]; ... }
            - Raw TOML string (escape hatch)
          These are merged (after the primary bindings.toml) by sshenv.
        '';
      };
    };
    worktree-setup.enable = mkEnable "worktree setup helper";
  };

  config = {
    warnings = optional (
      cfg.pi.enable && config.myConfig.development.pi.enable
    ) "myConfig.cliTools.utilities.pi.enable is redundant when myConfig.development.pi.enable is true.";

    # Direnv
    programs.direnv = mkIf cfg.direnv.enable {
      enable = true;
      nix-direnv.enable = cfg.direnv.nix-direnv;
    };

    # Package installs
    home.packages = mkMerge [
      (mkIf cfg.jq.enable [ pkgs.jq ])
      (mkIf cfg.parallel.enable [ pkgs.parallel ])
      (mkIf cfg.write-good.enable [ pkgs.write-good ])
      (mkIf cfg.cronstrue.enable [ pkgs.cronstrue-custom ])
      (mkIf cfg.clippier.enable [ pkgs.clippier ])
      (mkIf cfg.cloc.enable [ pkgs.cloc ])
      (mkIf cfg.watchexec.enable [ pkgs.watchexec ])
      (mkIf cfg.lsof.enable [ pkgs.lsof ])
      (mkIf cfg.killall.enable [ pkgs.killall ])
      (mkIf cfg.nix-search.enable [ pkgs.nix-search ])
      (mkIf cfg.media.ffmpeg.enable [ pkgs.unstable.ffmpeg ])
      (mkIf cfg.media.flac.enable [ pkgs.flac ])
      (mkIf cfg.media.mediainfo.enable [ pkgs.mediainfo ])
      (mkIf cfg.opencodeUpstream.enable [
        pkgs.unstable.opencode
      ])
      (mkIf cfg.pi.enable [ pkgs.pi ])
      (mkIf cfg.sshenv.enable [ pkgs.sshenv ])
      (mkIf cfg.worktree-setup.enable [ pkgs.worktree-setup ])
    ];

    # Shim dir goes first in PATH so sshenv shims shadow nix-profile,
    # ~/.cargo/bin, ~/.local/bin, etc. Contributed via the internal
    # homeModules.shell.shared.sessionPath hook, which the shared shell
    # module concatenates BEFORE user-facing defaults when building
    # home.sessionPath (see home/modules/shell/shared.nix).
    homeModules.shell.shared.sessionPath = mkIf cfg.sshenv.enable [ "$HOME/.sshenv/bin" ];

    # Deploy declarative bindings fragments into bindings.d/.
    # When autoBindings is enabled, we provide a base set of pi-* bindings.
    # User declarativeBindings are merged on top (user wins on name conflicts).
    home.file = mkIf cfg.sshenv.enable (
      let
        base = if cfg.sshenv.autoBindings then autoSshenvBindings else { };
        final = base // cfg.sshenv.declarativeBindings;
      in
      lib.mapAttrs' (name: value: {
        name = ".sshenv/bindings.d/${name}.toml";
        value.text = bindingsFragmentToToml name value;
      }) final
    );

    # Ensure shims are regenerated whenever bindings change.
    home.activation.sshenvSyncShims = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.sshenv}/bin/sshenv shims sync 2>/dev/null || true
    '';
  };
}
