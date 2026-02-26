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
  myLib,
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
    homebrew-linear
    ;

  # Build extra overlays from meta.extraModules (for packages like nix-minecraft)
  extraOverlayMap = {
    "nix-minecraft" = [ inputs.nix-minecraft.overlay ];
  };

  extraOverlays = builtins.concatLists (
    map (m: extraOverlayMap.${m} or [ ]) (meta.extraModules or [ ])
  );
in
nix-darwin.lib.darwinSystem {
  system = meta.system;
  specialArgs = { inherit inputs myLib; };
  modules = [
    ../hosts/${name}
    home-manager.darwinModules.home-manager
    nix-homebrew.darwinModules.nix-homebrew
    {
      nixpkgs.config = {
        allowUnfree = true;
        android_sdk.accept_license = true;
      };
      nixpkgs.overlays = extraOverlays ++ (mkOverlays meta.system nixpkgs-darwin);
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
            "schpet/homebrew-tap" = homebrew-linear;
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
            inherit inputs myLib;
            osConfig = config;
          };
        };

        homebrew.taps = builtins.attrNames config.nix-homebrew.taps;
      }
    )
  ];
}
