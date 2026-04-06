{
  config,
  lib,
  ...
}:

with lib;

let
  shellCfg = config.myConfig.shell;
  zshEnabled = shellCfg.zsh.enable || shellCfg.default == "zsh";

  completionCommands =
    if shellCfg.shared.completions.enable then
      unique (config.homeModules.shell.shared.completionCommands ++ shellCfg.shared.completions.commands)
    else
      [ ];

  completionInit = concatMapStringsSep "\n" (command: ''
    if command -v ${command} >/dev/null 2>&1; then
      source <(${command} completion zsh)
    fi
  '') completionCommands;
in
{
  options.myConfig.shell.zsh.enable = mkEnableOption "Zsh shell configuration";

  config = mkIf zshEnabled {
    programs.zsh = {
      enable = true;
      shellAliases = config.homeModules.shell.resolvedAliases;
      enableCompletion = shellCfg.shared.completions.enable;
      initContent = ''
        ${config.homeModules.shell.shared.zshInit}
        ${shellCfg.shared.zshInit}
        ${completionInit}
      '';
    };
  };
}
