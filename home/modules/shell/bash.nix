{
  config,
  lib,
  ...
}:

let
  shellCfg = config.myConfig.shell;
  bashEnabled = shellCfg.bash.enable || shellCfg.default == "bash";

  completionCommands =
    if shellCfg.shared.completions.enable then
      lib.unique (
        config.myConfig.shell.contrib.completionCommands ++ shellCfg.shared.completions.commands
      )
    else
      [ ];

  completionInit = lib.concatMapStringsSep "\n" (command: ''
    if command -v ${command} >/dev/null 2>&1; then
      source <(${command} completion bash)
    fi
  '') completionCommands;
in
{
  options.myConfig.shell.bash.enable = lib.mkEnableOption "Bash shell configuration";

  config = lib.mkIf bashEnabled {
    programs.bash = {
      enable = true;
      enableCompletion = shellCfg.shared.completions.enable;
      shellAliases = config.myConfig.shell.resolved.aliases;
      initExtra = ''
        ${config.myConfig.shell.contrib.bashInit}
        ${shellCfg.shared.bashInit}
        ${completionInit}
      '';
    };
  };
}
