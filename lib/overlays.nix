# Main overlay entry point
# Simplifies passing flake inputs to the automatic overlay discovery system
#
# Source-built packages are auto-discovered from lib/source-builds/configs/*.json.
# Only complex/custom overlays need explicit wiring here.
{
  lib,
  nixpkgs-unstable,
  # All flake inputs -- source-build auto-discovery looks up inputs by name
  flakeInputs,
  # Complex overlays that need explicit input wiring
  rust-overlay ? null,
  zellij-fork ? null,
  cronstrue-src ? null,
  firefox-darwin ? null,
  # Optional overlay configuration
  enableRust ? true,
  enableGithubReleases ? true,
  enableSourceBuilds ? true,
  enableZellijFork ? false,
  enableCronstrue ? true,
  enableFirefoxDarwin ? true,
  enableMinecraftPlugins ? true,
}:
let
  # Bundle inputs for overlays that need them
  # Source-builds auto-discovery uses flakeInputs directly
  # Complex overlays use named inputs
  inputs = {
    inherit
      nixpkgs-unstable
      rust-overlay
      zellij-fork
      firefox-darwin
      ;
    cronstrue = cronstrue-src;
  }
  // flakeInputs;

  # Helper to extract git input metadata from flake.lock
  # Always uses root flake.lock with unified flake structure
  mkGitInput = import ./mk-git-input.nix { lockFile = ../flake.lock; };

  # Import all overlay functions (these must be imported here, not in mkOverlays.nix)
  overlayFunctions = {
    rust = import ./overlays/rust.nix;
    github-releases = import ./overlays/github-releases.nix;
    source-builds = import ./overlays/source-builds.nix;
    zellij = import ./overlays/zellij.nix;
    cronstrue = import ./overlays/cronstrue.nix;
    firefox-darwin = import ./overlays/firefox-darwin.nix;
    minecraft-plugins = import ./overlays/minecraft-plugins.nix;
  };

  mkOverlaysLib = import ./mkOverlays.nix {
    inherit
      lib
      inputs
      mkGitInput
      overlayFunctions
      ;
  };
in
mkOverlaysLib.mkOverlays {
  inherit
    enableRust
    enableGithubReleases
    enableSourceBuilds
    enableZellijFork
    enableCronstrue
    enableFirefoxDarwin
    enableMinecraftPlugins
    ;
}
