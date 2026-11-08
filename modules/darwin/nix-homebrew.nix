# nix-homebrew tap wiring for Darwin hosts.
#
# Taps are pinned to flake inputs so `brew` never mutates them. Individual
# casks/formulae are declared by feature modules (modules/darwin/*.nix) and
# the host's default.nix.
{
  config,
  lib,
  inputs,
  ...
}:
{
  nix-homebrew = {
    enable = config.myConfig.darwin.homebrew.enable;
    enableRosetta = config.myConfig.darwin.homebrew.rosetta.enable;
    user = config.myConfig.username;
    mutableTaps = false;
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      # Current Homebrew treats the upstream :ventura requirement as a minimum.
      "nikitabobko/homebrew-tap" = inputs.homebrew-aerospace;
      "FelixKratz/homebrew-formulae" = inputs.homebrew-felixkratz;
      "schpet/homebrew-tap" = inputs.homebrew-linear;
    };
  };

  homebrew.taps = lib.mkIf config.myConfig.darwin.homebrew.enable (
    builtins.attrNames config.nix-homebrew.taps
  );
}
