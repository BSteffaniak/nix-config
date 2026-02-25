# Creates a standalone home-manager configuration for a host.
#
# Arguments:
#   name       - The host directory name (e.g., "ubuntu-laptop")
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
  inherit (inputs) nixpkgs home-manager;
in
home-manager.lib.homeManagerConfiguration {
  pkgs = import nixpkgs {
    system = meta.system;
    config.allowUnfree = true;
    overlays = mkOverlays meta.system nixpkgs;
  };
  modules = [
    ../hosts/${name}/home.nix
  ];
  extraSpecialArgs = {
    inherit inputs myLib;
  };
}
