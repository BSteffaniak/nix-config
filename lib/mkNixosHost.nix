# Creates a NixOS system configuration for a host.
#
# Arguments:
#   name       - The host directory name (e.g., "nixos-desktop")
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
  inherit (inputs) nixpkgs home-manager;

  # Build extra module list from meta.extraModules
  extraModuleMap = {
    "nix-minecraft" = inputs.nix-minecraft.nixosModules.minecraft-servers;
  };

  extraNixosModules = map (m: extraModuleMap.${m}) (meta.extraModules or [ ]);

  # Build extra overlays from meta.extraModules
  extraOverlayMap = {
    "nix-minecraft" = [ inputs.nix-minecraft.overlay ];
  };

  extraOverlays = builtins.concatLists (
    map (m: extraOverlayMap.${m} or [ ]) (meta.extraModules or [ ])
  );
in
nixpkgs.lib.nixosSystem {
  system = meta.system;
  specialArgs = { inherit inputs; };
  modules = [
    ../hosts/${name}
    home-manager.nixosModules.home-manager
    {
      nixpkgs.config = {
        allowUnfree = true;
        android_sdk.accept_license = true;
      };
      nixpkgs.overlays = extraOverlays ++ (mkOverlays meta.system nixpkgs);
    }
    (
      { config, ... }:
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "backup";
          users.${meta.username} = {
            imports = [
              ../home/nixos
              ../hosts/${name}/home.nix
            ];
          };
          extraSpecialArgs = {
            inherit inputs;
            osConfig = config;
          };
        };
      }
    )
  ]
  ++ extraNixosModules;
}
