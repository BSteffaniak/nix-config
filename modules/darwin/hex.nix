# Installation follows the home.nix flag; retain the legacy system flag for compatibility.
{ config, lib, ... }:
let
  enabled = lib.any (home: home.myConfig.desktop.hex.enable) (
    lib.attrValues config.home-manager.users
  );
in
{
  options.myConfig.darwin.hex.enable =
    lib.mkEnableOption "Hex via Homebrew (prefer myConfig.desktop.hex.enable in home.nix)";

  config = lib.mkIf (enabled || config.myConfig.darwin.hex.enable) {
    homebrew.casks = [ "kitlangton-hex" ];
    myConfig.darwin.homebrew.enable = true;
  };
}
