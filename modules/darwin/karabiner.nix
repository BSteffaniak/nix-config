{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  options.myConfig.darwin.karabiner = {
    enable = mkEnableOption "Karabiner-Elements keyboard customization";
  };

  config = mkIf config.myConfig.darwin.karabiner.enable {
    # Install via Homebrew cask - the nix-darwin services.karabiner-elements
    # module has issues with missing LaunchAgents in the nixpkgs derivation
    homebrew.casks = [ "karabiner-elements" ];
  };
}
