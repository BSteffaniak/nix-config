# Example overlay configuration for hosts
# Copy this file to your host directory (e.g., hosts/nixos-desktop/overlays.nix)
# and customize the flags to disable overlays you don't need.
#
# Then in your host's flake, import this file instead of the default overlay configuration.

{
  nixpkgs-unstable,
  ra-multiplex-src,
  rust-overlay,
}:

# Example 1: Disable Rust overlay (saves build time if you don't use Rust)
import ../../lib/overlays.nix {
  inherit
    nixpkgs-unstable
    ra-multiplex-src
    rust-overlay
    ;
  enableRust = false;
  enableGithubReleases = true;
  enableRaMultiplex = true;
}

# Example 2: Only enable unstable packages (minimal setup)
# import ../../lib/overlays.nix {
#   inherit nixpkgs-unstable ra-multiplex-src rust-overlay;
#   enableRust = false;
#   enableGithubReleases = false;
#   enableRaMultiplex = false;
# }

# Example 3: Enable everything (default behavior)
# import ../../lib/overlays.nix {
#   inherit nixpkgs-unstable ra-multiplex-src rust-overlay;
#   enableRust = true;
#   enableGithubReleases = true;
#   enableRaMultiplex = true;
# }
