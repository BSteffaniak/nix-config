{
  config,
  lib,
  myLib,
  pkgs,
  ...
}:

let
  defaultShell = myLib.defaultShell;

  cfg = config.myConfig.shell;
  sharedCfg = cfg.contrib;

  mergedAliases = sharedCfg.aliases // cfg.shared.aliases;
  mergedSessionVariables = sharedCfg.sessionVariables // cfg.shared.sessionVariables;
  mergedSessionPath = lib.unique (sharedCfg.sessionPath ++ cfg.shared.sessionPath);
  mergedFunctions = sharedCfg.functions // cfg.shared.functions;

  shellPackages = {
    fish = pkgs.fish;
    bash = pkgs.bashInteractive;
    zsh = pkgs.zsh;
    nushell = pkgs.nushell;
  };

  shellBinaries = {
    fish = "fish";
    bash = "bash";
    zsh = "zsh";
    nushell = "nu";
  };

  isShellEnabled =
    shell:
    (
      lib.hasAttrByPath [
        shell
        "enable"
      ] cfg
      && cfg.${shell}.enable
    )
    || cfg.default == shell;
in
{
  options.myConfig.shell = {
    default = lib.mkOption {
      type = lib.types.enum [
        "fish"
        "bash"
        "zsh"
        "nushell"
      ];
      default = defaultShell;
      description = "Default shell";
    };

    warnOnStandaloneLoginShellMismatch = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Warn in standalone Home Manager when login shell does not match myConfig.shell.default";
    };

    shared = {
      aliases = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Aliases shared across fish, bash, zsh, and nushell";
      };

      sessionVariables = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Session environment variables shared across shells";
      };

      sessionPath = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "$HOME/.local/bin"
          "$HOME/.npm-packages/bin"
          "$HOME/.bun/bin"
        ];
        description = "Session PATH entries shared across shells";
      };

      functions = lib.mkOption {
        type = lib.types.attrsOf lib.types.lines;
        default = { };
        description = "Portable shell functions exposed as commands";
      };

      completions = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable completion support across shells";
        };

        useCarapace = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Use Carapace as a shared completion backend";
        };

        commands = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Commands to initialize via '<cmd> completion <shell>' hooks";
        };
      };

      bashInit = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Additional shared Bash initialization";
      };

      zshInit = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Additional shared Zsh initialization";
      };

      fishInit = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Additional shared Fish initialization";
      };

      nushellConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Additional shared Nushell config";
      };

      nushellEnv = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Additional shared Nushell environment config";
      };
    };
  };

  # Internal: values other modules contribute (aliases, PATH entries, init
  # snippets). Host-facing `myConfig.shell.shared.*` wins on key collisions.
  options.myConfig.shell.resolved = {
    defaultShellPath = lib.mkOption {
      type = lib.types.str;
      default = "${pkgs.fish}/bin/fish";
      internal = true;
      description = "Resolved absolute path to the configured default shell";
    };

    aliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      internal = true;
      description = "Merged aliases from module contributions and user config";
    };
  };

  options.myConfig.shell.contrib = {
    aliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      internal = true;
      description = "Alias contributions from modules";
    };

    sessionVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      internal = true;
      description = "Session variable contributions from modules";
    };

    sessionPath = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      internal = true;
      description = "PATH entry contributions from modules";
    };

    functions = lib.mkOption {
      type = lib.types.attrsOf lib.types.lines;
      default = { };
      internal = true;
      description = "Portable function contributions from modules";
    };

    completionCommands = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      internal = true;
      description = "Completion command contributions from modules";
    };

    bashInit = lib.mkOption {
      type = lib.types.lines;
      default = "";
      internal = true;
      description = "Bash init contributions from modules";
    };

    zshInit = lib.mkOption {
      type = lib.types.lines;
      default = "";
      internal = true;
      description = "Zsh init contributions from modules";
    };

    fishInit = lib.mkOption {
      type = lib.types.lines;
      default = "";
      internal = true;
      description = "Fish init contributions from modules";
    };

    nushellConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      internal = true;
      description = "Nushell config contributions from modules";
    };

    nushellEnv = lib.mkOption {
      type = lib.types.lines;
      default = "";
      internal = true;
      description = "Nushell env contributions from modules";
    };
  };

  config = {
    myConfig.shell.resolved.defaultShellPath = "${shellPackages.${cfg.default}}/bin/${shellBinaries.${cfg.default}}";
    myConfig.shell.resolved.aliases = mergedAliases;

    home.sessionVariables = mergedSessionVariables;
    home.sessionPath = mergedSessionPath;

    home.packages = lib.mapAttrsToList (name: body: pkgs.writeShellScriptBin name body) mergedFunctions;

    programs.carapace = lib.mkIf (cfg.shared.completions.enable && cfg.shared.completions.useCarapace) {
      enable = true;
      enableBashIntegration = isShellEnabled "bash";
      enableFishIntegration = isShellEnabled "fish";
      enableNushellIntegration = isShellEnabled "nushell";
      enableZshIntegration = isShellEnabled "zsh";
    };
  };
}
