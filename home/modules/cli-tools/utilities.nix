{
  config,
  lib,
  pkgs,
  myLib,
  osConfig ? { },
  ...
}:

let
  cfg = config.myConfig.cliTools.utilities;

  mkEnable = myLib.mkEnableOption' cfg.enableAll;
  mkMediaEnable = myLib.mkEnableOption' cfg.media.enableAll;
  useMacOSKeychainTrustStore =
    pkgs.stdenv.hostPlatform.isDarwin
    && (lib.attrByPath [ "myConfig" "darwin" "cloudflareWarp" "enable" ] false osConfig);
  sendsafelyJava = pkgs.sendsafely-java.override {
    inherit useMacOSKeychainTrustStore;
  };

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
        "opencode-openai-api-fast"
      ];
      openrouter = [
        "opencode-openrouter"
      ];
      opencode-zen = [
        "opencode-zen"
      ];
      xai = [
        "opencode-grok-4-6"
        "opencode-grok-code-fast"
      ];
    };
  };
in
{
  options.myConfig.cliTools.utilities = {
    enableAll = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable all utility tools (can be overridden per-tool)";
    };

    direnv = {
      enable = mkEnable "Direnv for per-directory environments";
      nix-direnv = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable nix-direnv integration";
      };
    };

    jq.enable = mkEnable "JSON processor";
    parallel.enable = mkEnable "GNU parallel";
    writeGood.enable = mkEnable "writing quality checker";
    cronstrue.enable = mkEnable "cron expression diagnostic tool";
    sendsafely.enable = mkEnable "SendSafely Java CLI";
    clippier.enable = mkEnable "Clippier CI helper";
    gitSshripped.enable = mkEnable "git-sshripped (SSH-key based git file encryption)";
    cloc.enable = mkEnable "lines of code counter";
    watchexec.enable = mkEnable "file watcher/executor";
    lsof.enable = mkEnable "list open files utility";
    killall.enable = mkEnable "killall utility";
    nixSearch.enable = mkEnable "Nix package search";

    media = {
      enableAll = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enableAll;
        description = "Enable all media tools (can be overridden per-tool)";
      };

      ffmpeg.enable = mkMediaEnable "FFmpeg media processor";
      flac.enable = mkMediaEnable "FLAC codec";
      mediainfo.enable = mkMediaEnable "media info analyzer";
    };

    opencodeUpstream.enable = mkEnable "upstream OpenCode CLI";
    codexUpstream.enable = mkEnable "upstream Codex CLI";
    pi.enable = mkEnable "Pi coding agent CLI without managed config";
    sshenv = {
      enable = mkEnable "sshenv SSH-key-backed env vault";

      autoBindings = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Automatically provide useful bindings for pi-* commands (and common opencode aliases)
          when sshenv is enabled. Set to false to fully control bindings yourself.
        '';
      };

      unencryptedSshKeys = lib.mkOption {
        type = lib.types.enum [
          "allow"
          "warn"
          "deny"
        ];
        default = "allow";
        description = ''
          Policy sshenv applies to authorized vault recipient SSH private keys
          that have no passphrase, written to ~/.sshenv/config.toml as
          [security] unencrypted_ssh_keys.

          "allow" silences the startup warning, "warn" prints it on every
          command that decrypts secrets, and "deny" refuses to run.
        '';
      };

      declarativeBindings = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.oneOf [
            (lib.types.attrsOf (lib.types.listOf lib.types.str)) # nice form: profile -> [commands]
            lib.types.lines # raw TOML escape hatch
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
              "pi-grok-4.6"
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
    worktreeSetup.enable = mkEnable "worktree setup helper";
  };

  config = {
    warnings = lib.optional (
      cfg.pi.enable && config.myConfig.development.pi.enable
    ) "myConfig.cliTools.utilities.pi.enable is redundant when myConfig.development.pi.enable is true.";

    # Direnv
    programs.direnv = lib.mkIf cfg.direnv.enable {
      enable = true;
      nix-direnv.enable = cfg.direnv.nix-direnv;
    };

    # Package installs
    home.packages = lib.mkMerge [
      (lib.mkIf cfg.jq.enable [ pkgs.jq ])
      (lib.mkIf cfg.parallel.enable [ pkgs.parallel ])
      (lib.mkIf cfg.writeGood.enable [ pkgs.write-good ])
      (lib.mkIf cfg.cronstrue.enable [ pkgs.cronstrue-custom ])
      (lib.mkIf cfg.sendsafely.enable [ sendsafelyJava ])
      (lib.mkIf cfg.clippier.enable [ pkgs.clippier ])
      (lib.mkIf cfg.gitSshripped.enable [ pkgs.git-sshripped ])
      (lib.mkIf cfg.cloc.enable [ pkgs.cloc ])
      (lib.mkIf cfg.watchexec.enable [ pkgs.watchexec ])
      (lib.mkIf cfg.lsof.enable [ pkgs.lsof ])
      (lib.mkIf cfg.killall.enable [ pkgs.killall ])
      (lib.mkIf cfg.nixSearch.enable [ pkgs.nix-search ])
      (lib.mkIf cfg.media.ffmpeg.enable [ pkgs.unstable.ffmpeg ])
      (lib.mkIf cfg.media.flac.enable [ pkgs.flac ])
      (lib.mkIf cfg.media.mediainfo.enable [ pkgs.mediainfo ])
      (lib.mkIf cfg.opencodeUpstream.enable [
        pkgs.unstable.opencode
      ])
      (lib.mkIf cfg.codexUpstream.enable [ pkgs.codex-dev ])
      (lib.mkIf cfg.pi.enable [ pkgs.pi ])
      (lib.mkIf cfg.sshenv.enable [ pkgs.sshenv ])
      (lib.mkIf cfg.worktreeSetup.enable [ pkgs.worktree-setup ])
    ];

    # Shim dir goes first in PATH so sshenv shims shadow nix-profile,
    # ~/.cargo/bin, ~/.local/bin, etc. Contributed via the internal
    # myConfig.shell.contrib.sessionPath hook, which the shared shell
    # module concatenates BEFORE user-facing defaults when building
    # home.sessionPath (see home/modules/shell/shared.nix).
    myConfig.shell.contrib.sessionPath = lib.mkIf cfg.sshenv.enable [ "$HOME/.sshenv/bin" ];

    # Deploy declarative bindings fragments into bindings.d/, plus the
    # security policy file at ~/.sshenv/config.toml.
    # When autoBindings is enabled, we provide a base set of pi-* bindings.
    # User declarativeBindings are merged on top (user wins on name conflicts).
    home.file = lib.mkIf cfg.sshenv.enable (
      let
        base = if cfg.sshenv.autoBindings then autoSshenvBindings else { };
        final = base // cfg.sshenv.declarativeBindings;
      in
      lib.mapAttrs' (name: value: {
        name = ".sshenv/bindings.d/${name}.toml";
        value.text = bindingsFragmentToToml name value;
      }) final
      // {
        ".sshenv/config.toml".text = ''
          [security]
          unencrypted_ssh_keys = "${cfg.sshenv.unencryptedSshKeys}"
        '';
      }
    );

    # Ensure shims are regenerated whenever bindings change.
    home.activation.sshenvSyncShims = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.sshenv}/bin/sshenv shims sync 2>/dev/null || true
    '';
  };
}
