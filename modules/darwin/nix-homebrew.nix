# nix-homebrew tap wiring for Darwin hosts.
#
# Taps are pinned to flake inputs so `brew` never mutates them. Individual
# casks/formulae are declared by feature modules (modules/darwin/*.nix) and
# the host's default.nix.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  # Work around nikitabobko/homebrew-tap#4 changing the minimum macOS
  # requirement into an exact Ventura-only requirement.
  patchedHomebrewAerospace = pkgs.runCommand "homebrew-aerospace-patched" { } ''
    cp -R ${inputs.homebrew-aerospace} "$out"
    chmod -R u+w "$out"
    substituteInPlace "$out/Casks/aerospace.rb" \
      --replace-fail \
      'depends_on macos: :ventura' \
      'depends_on macos: ">= :ventura"'
  '';
in
{
  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = config.myConfig.username;
    mutableTaps = false;
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "nikitabobko/homebrew-tap" = patchedHomebrewAerospace;
      "FelixKratz/homebrew-formulae" = inputs.homebrew-felixkratz;
      "schpet/homebrew-tap" = inputs.homebrew-linear;
    };
  };

  homebrew.taps = builtins.attrNames config.nix-homebrew.taps;
}
