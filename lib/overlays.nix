# Main overlay entry point
# Simplifies passing flake inputs to the automatic overlay discovery system
{
  lib,
  nixpkgs-unstable,
  ra-multiplex-src,
  tone-clone-src ? null,
  rust-overlay ? null,
  zellij-fork ? null,
  cronstrue-src ? null,
  firefox-darwin ? null,
  # Optional overlay configuration
  enableRust ? true,
  enableGithubReleases ? true,
  enableRaMultiplex ? true,
  enableToneClone ? true,
  enableZellijFork ? false,
  enableCronstrue ? true,
  enableFirefoxDarwin ? true,
  enableMinecraftPlugins ? true,
}:
let
  # Bundle all inputs into a single attrset for easier passing
  inputs = {
    inherit
      nixpkgs-unstable
      rust-overlay
      zellij-fork
      firefox-darwin
      ;
    ra-multiplex = ra-multiplex-src;
    tone-clone = tone-clone-src;
    cronstrue = cronstrue-src;
  };

  # Helper to extract git input metadata from flake.lock
  # Always uses root flake.lock with unified flake structure
  mkGitInput = import ./mk-git-input.nix { lockFile = ../flake.lock; };

  # Import all overlay functions (these must be imported here, not in mkOverlays.nix)
  overlayFunctions = {
    rust = import ./overlays/rust.nix;
    github-releases = import ./overlays/github-releases.nix;
    ra-multiplex = import ./overlays/ra-multiplex.nix;
    tone-clone = import ./overlays/tone-clone.nix;
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
    enableRaMultiplex
    enableToneClone
    enableZellijFork
    enableCronstrue
    enableFirefoxDarwin
    enableMinecraftPlugins
    ;
}
