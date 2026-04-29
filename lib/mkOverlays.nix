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
      enableGithubReleases ? true,
      enableSourceBuilds ? true,
      enableZellijFork ? false,
      enableCronstrue ? true,
      enableFirefoxDarwin ? true,
      enableMinecraftPlugins ? true,
    }:
    let
      # Core overlays (always enabled)
      coreOverlays = [
        # Unstable packages overlay (core functionality)
        (
          final: prev:
          let
            unstablePkgs = import inputs.nixpkgs-unstable {
              system = prev.stdenv.hostPlatform.system;
              config.allowUnfree = true;
            };
          in
          {
            unstable = unstablePkgs;
            fish = unstablePkgs.fish;
            fishPlugins =
              if prev.stdenv.isDarwin then
                prev.fishPlugins
                // {
                  bass = prev.fishPlugins.bass.overrideAttrs (_: {
                    doCheck = false;
                  });
                }
              else
                prev.fishPlugins;
          }
        )
      ];

      # List of available overlays
      # Overlay functions are imported in lib/overlays.nix and passed here
      availableOverlays = [
        {
          enable = enableRust;
          overlay = overlayFunctions.rust;
        }
        {
          enable = enableGithubReleases;
          overlay = overlayFunctions.github-releases;
        }
        {
          enable = enableSourceBuilds;
          overlay = overlayFunctions.source-builds;
        }
        {
          enable = enableZellijFork;
          overlay = overlayFunctions.zellij;
        }
        {
          enable = enableCronstrue;
          overlay = overlayFunctions.cronstrue;
        }
        {
          enable = enableFirefoxDarwin;
          overlay = overlayFunctions.firefox-darwin;
        }
        {
          enable = enableMinecraftPlugins;
          overlay = overlayFunctions.minecraft-plugins;
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
