{
  config,
  lib,
  ...
}:

let
  shellCfg = config.myConfig.shell;
  zshEnabled = shellCfg.zsh.enable || shellCfg.default == "zsh";

  completionCommands =
    if shellCfg.shared.completions.enable then
      lib.unique (
        config.myConfig.shell.contrib.completionCommands ++ shellCfg.shared.completions.commands
      )
    else
      [ ];

  completionInit = lib.concatMapStringsSep "\n" (command: ''
    if command -v ${command} >/dev/null 2>&1; then
      source <(${command} completion zsh)
    fi
  '') completionCommands;
in
{
  options.myConfig.shell.zsh.enable = lib.mkEnableOption "Zsh shell configuration";

  config = lib.mkIf zshEnabled {
    programs.zsh = {
      enable = true;
      shellAliases = config.myConfig.shell.resolved.aliases;
      enableCompletion = shellCfg.shared.completions.enable;
      initContent = ''
        ${config.myConfig.shell.contrib.zshInit}
        ${shellCfg.shared.zshInit}
        ${completionInit}
      '';
    };
  };
}
