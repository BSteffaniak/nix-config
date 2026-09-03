# All overlays applied to every host's nixpkgs.
#
# Each file in this directory is `inputs: final: prev: { ... }` (or, for
# rust, a list of overlays). Order matters: later overlays can see earlier
# ones through `final`.
{ inputs }:
let
  overlay = file: import file { inherit inputs; };
in
[
  (overlay ./unstable.nix)
  (overlay ./darwin-fixes.nix)
  (overlay ./firefox-darwin.nix)
]
++ (overlay ./rust.nix)
++ [
  (overlay ./source-builds.nix)
  (overlay ./cronstrue.nix)
  (overlay ./sendsafely-java.nix)
  (overlay ./github-releases.nix)
  (overlay ./minecraft-plugins.nix)
]
