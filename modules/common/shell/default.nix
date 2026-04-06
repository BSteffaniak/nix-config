{
  config,
  lib,
  pkgs,
  options,
  ...
}:

with lib;

let
  cfg = config.myConfig.shell;

  shellPackages = {
    fish = pkgs.fish;
    bash = pkgs.bashInteractive;
    zsh = pkgs.zsh;
    nushell = pkgs.nushell;
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

  enabledShellPackages = unique (
    (optional (isShellEnabled "fish") shellPackages.fish)
    ++ (optional (isShellEnabled "bash") shellPackages.bash)
    ++ (optional (isShellEnabled "zsh") shellPackages.zsh)
    ++ (optional (isShellEnabled "nushell") shellPackages.nushell)
  );

  defaultShellPackage = shellPackages.${cfg.default};

  hasOption = path: hasAttrByPath path options;
in
{
  imports = [
    ./bash.nix
    ./fish.nix
    ./nushell.nix
    ./zsh.nix
    ./git.nix
    ./ssh.nix
  ];

  options.myConfig.shell = {
    enable = mkEnableOption "Shell configuration";

    default = mkOption {
      type = types.enum [
        "fish"
        "bash"
        "zsh"
        "nushell"
      ];
      default = "fish";
      description = "Default login shell";
    };

    shared = {
      aliases = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Shell aliases shared across supported shells";
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
          description = "Enable shell completion support";
        };

        useCarapace = mkOption {
          type = types.bool;
          default = true;
          description = "Use Carapace as the shared completion engine";
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
        description = "Additional shared Nushell environment configuration";
      };
    };
  };

  config = mkMerge [
    (optionalAttrs
      (hasOption [
        "environment"
        "shells"
      ])
      {
        environment.shells = enabledShellPackages;
      }
    )

    (optionalAttrs
      (hasOption [
        "environment"
        "pathsToLink"
      ])
      {
        environment.pathsToLink = mkIf (isShellEnabled "bash" || isShellEnabled "zsh") (
          (optional (isShellEnabled "bash") "/share/bash-completion")
          ++ (optional (isShellEnabled "zsh") "/share/zsh")
        );
      }
    )

    (optionalAttrs
      (hasOption [
        "users"
        "defaultUserShell"
      ])
      {
        users.defaultUserShell = mkDefault defaultShellPackage;
      }
    )

    (optionalAttrs
      (hasOption [
        "users"
        "users"
      ])
      {
        users.users.${config.myConfig.username}.shell = mkDefault defaultShellPackage;
      }
    )
  ];
}
