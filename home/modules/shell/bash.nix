{
  config,
  lib,
  ...
}:

with lib;

let
  shellCfg = config.myConfig.shell;
  bashEnabled = shellCfg.bash.enable || shellCfg.default == "bash";

  completionCommands =
    if shellCfg.shared.completions.enable then
      unique (config.homeModules.shell.shared.completionCommands ++ shellCfg.shared.completions.commands)
    else
      [ ];

  completionInit = concatMapStringsSep "\n" (command: ''
    if command -v ${command} >/dev/null 2>&1; then
      source <(${command} completion bash)
    fi
  '') completionCommands;
in
{
  options.myConfig.shell.bash.enable = mkEnableOption "Bash shell configuration";

  config = mkIf bashEnabled {
    programs.bash = {
      enable = true;
      enableCompletion = shellCfg.shared.completions.enable;
      shellAliases = config.homeModules.shell.resolvedAliases;
      initExtra = ''
        ${config.homeModules.shell.shared.bashInit}
        ${shellCfg.shared.bashInit}
        ${completionInit}
      '';
    };
  };
}
