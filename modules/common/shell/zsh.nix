{
  lib,
  config,
  options,
  ...
}:

with lib;

let
  cfg = config.myConfig.shell;
  zshEnabled = cfg.zsh.enable || cfg.default == "zsh";
  hasZshProgramOption = hasAttrByPath [
    "programs"
    "zsh"
    "enable"
  ] options;
in
{
  options.myConfig.shell.zsh.enable = mkEnableOption "Zsh shell";

  config = optionalAttrs hasZshProgramOption (
    mkIf zshEnabled {
      programs.zsh.enable = true;
    }
  );
}
