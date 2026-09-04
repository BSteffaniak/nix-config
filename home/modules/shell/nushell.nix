{
  config,
  lib,
  ...
}:

let
  shellCfg = config.myConfig.shell;
  nushellEnabled = shellCfg.nushell.enable || shellCfg.default == "nushell";

  mergedSessionVariables =
    config.myConfig.shell.contrib.sessionVariables // shellCfg.shared.sessionVariables;

  mergedSessionPath = lib.unique (
    config.myConfig.shell.contrib.sessionPath ++ shellCfg.shared.sessionPath
  );

  toNushellPathLiteral =
    path:
    if lib.hasPrefix "$HOME/" path then
      "$\"($env.HOME)/${lib.removePrefix "$HOME/" path}\""
    else
      "\"${path}\"";

  additionalPathLiteral = lib.concatMapStringsSep " " toNushellPathLiteral mergedSessionPath;
in
{
  options.myConfig.shell.nushell.enable = lib.mkEnableOption "Nushell configuration";

  config = lib.mkIf nushellEnabled {
    programs.nushell = {
      enable = true;
      shellAliases = config.myConfig.shell.resolved.aliases;
      environmentVariables = mergedSessionVariables;
      extraEnv = ''
        $env.DIRENV_LOG_FORMAT = ""

        # Nix system paths (POSIX shells get these from set-environment/nix-daemon.sh,
        # but nushell cannot source POSIX shell scripts)
        let nix_paths = [
          $"($env.HOME)/.nix-profile/bin"
          $"/etc/profiles/per-user/($env.USER)/bin"
          "/run/current-system/sw/bin"
          "/nix/var/nix/profiles/default/bin"
        ] | where { |p| ($p | path exists) }
        $env.PATH = ($env.PATH | prepend $nix_paths)

        # Homebrew (POSIX shells get this from 'brew shellenv' in /etc/zshrc)
        let brew_paths = ["/opt/homebrew/bin" "/opt/homebrew/sbin"]
          | where { |p| ($p | path exists) }
        $env.PATH = ($env.PATH | append $brew_paths)

        # Custom session paths from nix modules
        let additional_path = [ ${additionalPathLiteral} ]
        $env.PATH = ($env.PATH | prepend $additional_path)

        ${config.myConfig.shell.contrib.nushellEnv}
        ${shellCfg.shared.nushellEnv}
      '';
      extraConfig = ''
        $env.config.show_banner = false

        $env.config.history = {
            file_format: "sqlite"
            isolation: true
        }

        ${config.myConfig.shell.contrib.nushellConfig}
        ${shellCfg.shared.nushellConfig}
      '';
    };
  };
}
