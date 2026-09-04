# System-level login shell configuration.
#
# Installs the enabled shells system-wide (so they can be login shells).
# Per-user shell configuration lives in home-manager under the same
# myConfig.shell.* option paths; the platform bridge (home/nixos,
# home/darwin) mirrors these flags into home-manager.
#
# NixOS-only pieces (users.defaultUserShell, programs.nushell) live in
# modules/nixos/system/shell.nix.
{
  config,
  lib,
  myLib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.shell;

  shellPackages = {
    fish = pkgs.fish;
    bash = pkgs.bashInteractive;
    zsh = pkgs.zsh;
    nushell = pkgs.nushell;
  };

  enabledShells = lib.filter (shell: cfg.${shell}.enable || cfg.default == shell) (
    lib.attrNames shellPackages
  );
  enabledShellPackages = map (shell: shellPackages.${shell}) enabledShells;
  isEnabled = shell: lib.elem shell enabledShells;
in
{
  options.myConfig.shell = {
    default = lib.mkOption {
      type = lib.types.enum (lib.attrNames shellPackages);
      default = myLib.defaultShell;
      description = "Default login shell";
    };

    fish.enable = lib.mkEnableOption "Fish shell";
    bash.enable = lib.mkEnableOption "Bash shell";
    zsh.enable = lib.mkEnableOption "Zsh shell";
    nushell.enable = lib.mkEnableOption "Nushell shell";

    # Internal: consumed by platform modules.
    enabledShells = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = enabledShells;
      internal = true;
      readOnly = true;
      description = "Shells enabled either explicitly or as the default";
    };

    defaultShellPackage = lib.mkOption {
      type = lib.types.package;
      default = shellPackages.${cfg.default};
      internal = true;
      readOnly = true;
      description = "Package providing the default login shell";
    };
  };

  config = {
    environment.shells = enabledShellPackages;
    environment.systemPackages = enabledShellPackages;

    environment.pathsToLink =
      (lib.optional (isEnabled "bash") "/share/bash-completion")
      ++ (lib.optional (isEnabled "zsh") "/share/zsh");

    # Required for the shell to work as a login shell on NixOS and to get
    # system integration on darwin.
    programs.fish.enable = isEnabled "fish";
    programs.zsh.enable = isEnabled "zsh";
  };
}
