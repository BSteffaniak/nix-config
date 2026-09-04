# Generate a `myConfig.darwin.<name>.enable` option that installs a Homebrew
# cask. Keeps the ten one-cask modules in modules/darwin from repeating the
# same boilerplate.
#
#   mkCaskModule { name = "googleChrome"; cask = "google-chrome"; description = "Google Chrome browser"; }
#
# Extra config can be layered on with `extraConfig = cfg: { ... }`.
{ lib }:
{
  name,
  cask,
  description,
  extraOptions ? { },
  extraConfig ? _cfg: { },
}:
{ config, ... }:
let
  cfg = config.myConfig.darwin.${name};
in
{
  options.myConfig.darwin.${name} = {
    enable = lib.mkEnableOption "${description} via Homebrew";
  }
  // extraOptions;

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        homebrew.casks = [ cask ];
        myConfig.darwin.homebrew.enable = true;
      }
      (extraConfig cfg)
    ]
  );
}
