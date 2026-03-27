# Example overlay configuration for hosts
# Copy this file to your host directory (e.g., hosts/nixos-desktop/overlays.nix)
# and customize the flags to disable overlays you don't need.
#
# Then in your host's flake, import this file instead of the default overlay configuration.
#
# NOTE: Source-built packages (ra-multiplex, tone-clone, worktree-setup, etc.)
# are auto-discovered from lib/source-builds/configs/*.json and do NOT need
# individual enable flags. They are all controlled by enableSourceBuilds.

{
  nixpkgs-unstable,
  flakeInputs,
  rust-overlay,
}:

# Example 1: Disable Rust overlay (saves build time if you don't use Rust)
import ../../lib/overlays.nix {
  inherit
    nixpkgs-unstable
    flakeInputs
    rust-overlay
    ;
  enableRust = false;
  enableGithubReleases = true;
  enableSourceBuilds = true;
}

# Example 2: Only enable unstable packages (minimal setup)
# import ../../lib/overlays.nix {
#   inherit nixpkgs-unstable flakeInputs rust-overlay;
#   enableRust = false;
#   enableGithubReleases = false;
#   enableSourceBuilds = false;
# }

# Example 3: Enable everything (default behavior)
# import ../../lib/overlays.nix {
#   inherit nixpkgs-unstable flakeInputs rust-overlay;
#   enableRust = true;
#   enableGithubReleases = true;
#   enableSourceBuilds = true;
# }
