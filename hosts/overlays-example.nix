# Example overlay configuration.
#
# This repository currently enables overlays from flake.nix via mkOverlays.
# If you want a custom overlay set, use this file as a starting point and wire
# it into flake.nix's mkOverlays function for the host(s) that need it.
{
  lib,
  nixpkgs-unstable,
  flakeInputs,
  rust-overlay ? null,
  zellij-fork ? null,
  cronstrue-src ? null,
  firefox-darwin ? null,
}:

# Example 1: disable the Rust overlay, but keep source builds and releases.
import ../lib/overlays.nix {
  inherit
    lib
    nixpkgs-unstable
    flakeInputs
    rust-overlay
    zellij-fork
    cronstrue-src
    firefox-darwin
    ;

  enableRust = false;
  enableGithubReleases = true;
  enableSourceBuilds = true;
  enableZellijFork = false;
  enableCronstrue = true;
  enableFirefoxDarwin = true;
  enableMinecraftPlugins = true;
}

# Example 2: only enable unstable packages (minimal setup)
# import ../lib/overlays.nix {
#   inherit lib nixpkgs-unstable flakeInputs rust-overlay;
#   enableRust = false;
#   enableGithubReleases = false;
#   enableSourceBuilds = false;
#   enableZellijFork = false;
#   enableCronstrue = false;
#   enableFirefoxDarwin = false;
#   enableMinecraftPlugins = false;
# }

# Example 3: enable everything (default behavior)
# import ../lib/overlays.nix {
#   inherit lib nixpkgs-unstable flakeInputs rust-overlay zellij-fork cronstrue-src firefox-darwin;
#   enableRust = true;
#   enableGithubReleases = true;
#   enableSourceBuilds = true;
#   enableZellijFork = true;
#   enableCronstrue = true;
#   enableFirefoxDarwin = true;
#   enableMinecraftPlugins = true;
# }
