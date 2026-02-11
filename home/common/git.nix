{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:

with lib;

{
  # Only configure git when system has git enabled (myConfig.shell.git.enable)
  # This provides per-user git configuration with sensible defaults
  # Override in host-specific home.nix files using homeModules.git options
  homeModules.git = mkIf osConfig.myConfig.shell.git.enable {
    enable = true;
    aliases = {
      set-master = "branch --set-upstream-to=origin/master";
    };
    # userName defaults to "Braden Steffaniak"
    # userEmail defaults to "BradenSteffaniak@gmail.com"
    # extraConfig defaults to { pull.rebase = true; core.autocrlf = "input"; }
  };
}
