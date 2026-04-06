{
  lib,
  config,
  options,
  ...
}:

with lib;

let
  cfg = config.myConfig.shell;
  nushellEnabled = cfg.nushell.enable || cfg.default == "nushell";
  hasNushellProgramOption = hasAttrByPath [
    "programs"
    "nushell"
    "enable"
  ] options;
in
{
  options.myConfig.shell.nushell.enable = mkEnableOption "Nushell shell";

  config = optionalAttrs hasNushellProgramOption (
    mkIf nushellEnabled {
      programs.nushell.enable = true;
    }
  );
}
