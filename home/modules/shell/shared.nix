{
  config,
  lib,
  myLib,
  pkgs,
  ...
}:

with lib;

let
  defaultShell = attrByPath [
    "defaults"
    "shell"
    "default"
  ] "nushell" myLib;

  cfg = config.myConfig.shell;
  sharedCfg = config.homeModules.shell.shared;

  mergedAliases = sharedCfg.aliases // cfg.shared.aliases;
  mergedSessionVariables = sharedCfg.sessionVariables // cfg.shared.sessionVariables;
  mergedSessionPath = unique (sharedCfg.sessionPath ++ cfg.shared.sessionPath);
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
      hasAttrByPath [
        shell
        "enable"
      ] cfg
      && cfg.${shell}.enable
    )
    || cfg.default == shell;
in
{
  options.myConfig.shell = {
    default = mkOption {
      type = types.enum [
        "fish"
        "bash"
        "zsh"
        "nushell"
      ];
      default = defaultShell;
      description = "Default shell";
    };

    warnOnStandaloneLoginShellMismatch = mkOption {
      type = types.bool;
      default = true;
      description = "Warn in standalone Home Manager when login shell does not match myConfig.shell.default";
    };

    shared = {
      aliases = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Aliases shared across fish, bash, zsh, and nushell";
      };

      sessionVariables = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Session environment variables shared across shells";
      };

      sessionPath = mkOption {
        type = types.listOf types.str;
        default = [
          "$HOME/.local/bin"
          "$HOME/.npm-packages/bin"
          "$HOME/.bun/bin"
        ];
        description = "Session PATH entries shared across shells";
      };

      functions = mkOption {
        type = types.attrsOf types.lines;
        default = { };
        description = "Portable shell functions exposed as commands";
      };

      completions = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable completion support across shells";
        };

        useCarapace = mkOption {
          type = types.bool;
          default = true;
          description = "Use Carapace as a shared completion backend";
        };

        commands = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Commands to initialize via '<cmd> completion <shell>' hooks";
        };
      };

      bashInit = mkOption {
        type = types.lines;
        default = "";
        description = "Additional shared Bash initialization";
      };

      zshInit = mkOption {
        type = types.lines;
        default = "";
        description = "Additional shared Zsh initialization";
      };

      fishInit = mkOption {
        type = types.lines;
        default = "";
        description = "Additional shared Fish initialization";
      };

      nushellConfig = mkOption {
        type = types.lines;
        default = "";
        description = "Additional shared Nushell config";
      };

      nushellEnv = mkOption {
        type = types.lines;
        default = "";
        description = "Additional shared Nushell environment config";
      };
    };
  };

  options.homeModules.shell = {
    defaultShellPath = mkOption {
      type = types.str;
      default = "${pkgs.fish}/bin/fish";
      internal = true;
      description = "Resolved absolute path to the configured default shell";
    };

    resolvedAliases = mkOption {
      type = types.attrsOf types.str;
      default = { };
      internal = true;
      description = "Merged aliases from shared module contributions and user config";
    };

    shared = {
      aliases = mkOption {
        type = types.attrsOf types.str;
        default = { };
        internal = true;
        description = "Alias contributions from modules";
      };

      sessionVariables = mkOption {
        type = types.attrsOf types.str;
        default = { };
        internal = true;
        description = "Session variable contributions from modules";
      };

      sessionPath = mkOption {
        type = types.listOf types.str;
        default = [ ];
        internal = true;
        description = "PATH entry contributions from modules";
      };

      functions = mkOption {
        type = types.attrsOf types.lines;
        default = { };
        internal = true;
        description = "Portable function contributions from modules";
      };

      completionCommands = mkOption {
        type = types.listOf types.str;
        default = [ ];
        internal = true;
        description = "Completion command contributions from modules";
      };

      bashInit = mkOption {
        type = types.lines;
        default = "";
        internal = true;
        description = "Bash init contributions from modules";
      };

      zshInit = mkOption {
        type = types.lines;
        default = "";
        internal = true;
        description = "Zsh init contributions from modules";
      };

      fishInit = mkOption {
        type = types.lines;
        default = "";
        internal = true;
        description = "Fish init contributions from modules";
      };

      nushellConfig = mkOption {
        type = types.lines;
        default = "";
        internal = true;
        description = "Nushell config contributions from modules";
      };

      nushellEnv = mkOption {
        type = types.lines;
        default = "";
        internal = true;
        description = "Nushell env contributions from modules";
      };
    };
  };

  config = {
    homeModules.shell.defaultShellPath = "${shellPackages.${cfg.default}}/bin/${shellBinaries.${cfg.default}}";
    homeModules.shell.resolvedAliases = mergedAliases;

    home.sessionVariables = mergedSessionVariables;
    home.sessionPath = mergedSessionPath;

    home.packages = mapAttrsToList (name: body: pkgs.writeShellScriptBin name body) mergedFunctions;

    programs.carapace = mkIf (cfg.shared.completions.enable && cfg.shared.completions.useCarapace) {
      enable = true;
      enableBashIntegration = isShellEnabled "bash";
      enableFishIntegration = isShellEnabled "fish";
      enableNushellIntegration = isShellEnabled "nushell";
      enableZshIntegration = isShellEnabled "zsh";
    };
  };
}
