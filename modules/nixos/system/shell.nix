# NixOS-only login shell wiring; see modules/common/shell.nix.
{ config, lib, ... }:

{
  users.defaultUserShell = lib.mkOverride 900 config.myConfig.shell.defaultShellPackage;

  # Home Manager owns user shell configuration and completions. The NixOS
  # generator also assumes the older Fish package layout from the system
  # channel, while our shared overlay supplies the newer Fish package.
  programs.fish.generateCompletions = false;
}
