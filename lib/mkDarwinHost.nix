# Creates a nix-darwin system configuration for a host.
#
# Arguments:
#   name       - The host directory name (e.g., "macbook-air")
#   meta       - The host's meta.nix attrset
#   inputs     - All flake inputs
#   mkOverlays - Function to create overlays for a given system
{
  name,
  meta,
  inputs,
  mkOverlays,
}:
let
  inherit (inputs)
    nixpkgs-darwin
    home-manager
    nix-darwin
    nix-homebrew
    homebrew-core
    homebrew-cask
    homebrew-aerospace
    homebrew-felixkratz
    ;
in
nix-darwin.lib.darwinSystem {
  system = meta.system;
  specialArgs = { inherit inputs; };
  modules = [
    ../hosts/${name}
    home-manager.darwinModules.home-manager
    nix-homebrew.darwinModules.nix-homebrew
    {
      nixpkgs.config = {
        allowUnfree = true;
        android_sdk.accept_license = true;
      };
      nixpkgs.overlays = mkOverlays meta.system nixpkgs-darwin;
    }
    (
      { config, ... }:
      let
        username = config.myConfig.username;
      in
      {
        nix-homebrew = {
          enable = true;
          enableRosetta = true;
          user = username;
          taps = {
            "homebrew/homebrew-core" = homebrew-core;
            "homebrew/homebrew-cask" = homebrew-cask;
            "nikitabobko/homebrew-tap" = homebrew-aerospace;
            "FelixKratz/homebrew-formulae" = homebrew-felixkratz;
          };
          mutableTaps = false;
        };

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "backup";
          users.${username} = {
            imports = [
              ../home/darwin
              ../hosts/${name}/home.nix
            ];
          };
          extraSpecialArgs = {
            inherit inputs;
            osConfig = config;
          };
        };

        homebrew.taps = builtins.attrNames config.nix-homebrew.taps;
      }
    )
  ];
}
