# Expose nixpkgs-unstable as `pkgs.unstable`, and pick a few packages from
# it wholesale.
{ inputs }:
final: prev:
let
  unstable = import inputs.nixpkgs-unstable {
    system = prev.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  inherit unstable;
  fish = unstable.fish;
}
