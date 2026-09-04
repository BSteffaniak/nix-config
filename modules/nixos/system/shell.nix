# NixOS-only login shell wiring; see modules/common/shell.nix.
{ config, lib, ... }:

{
  users.defaultUserShell = lib.mkOverride 900 config.myConfig.shell.defaultShellPackage;
}
