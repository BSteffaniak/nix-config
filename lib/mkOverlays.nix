# Automatic overlay system
# Each overlay should accept { inputs, enable, mkGitInput ... } and return a list of overlays
{
  lib,
  inputs,
  mkGitInput,
  overlayFunctions,
}:
{
  # Build overlays with optional components
  # Enable flags map to overlay filenames (e.g., enableRust -> rust.nix)
  mkOverlays =
    {
      enableRust ? true,
      enableOpencode ? true,
      enableRaMultiplex ? true,
      enableZellijFork ? false,
      enableCronstrue ? true,
    }:
    let
      # Core overlays (always enabled)
      coreOverlays = [
        # Unstable packages overlay (core functionality)
        (final: prev: {
          unstable = import inputs.nixpkgs-unstable {
            system = prev.stdenv.hostPlatform.system;
            config.allowUnfree = true;
          };
        })
      ];

      # List of available overlays
      # Overlay functions are imported in lib/overlays.nix and passed here
      availableOverlays = [
        {
          enable = enableRust;
          overlay = overlayFunctions.rust;
        }
        {
          enable = enableOpencode;
          overlay = overlayFunctions.opencode;
        }
        {
          enable = enableRaMultiplex;
          overlay = overlayFunctions.ra-multiplex;
        }
        {
          enable = enableZellijFork;
          overlay = overlayFunctions.zellij;
        }
        {
          enable = enableCronstrue;
          overlay = overlayFunctions.cronstrue;
        }
      ];

      # Load each enabled overlay
      loadOverlay =
        { enable, overlay }:
        if enable then
          overlay {
            inherit inputs mkGitInput;
            enable = true;
          }
        else
          [ ];

      # Load all enabled overlays
      autoOverlays = lib.flatten (map loadOverlay availableOverlays);
    in
    coreOverlays ++ autoOverlays;
}
