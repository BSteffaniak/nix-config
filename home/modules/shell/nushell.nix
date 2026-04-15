{
  config,
  lib,
  ...
}:

with lib;

let
  shellCfg = config.myConfig.shell;
  nushellEnabled = shellCfg.nushell.enable || shellCfg.default == "nushell";

  mergedSessionVariables =
    config.homeModules.shell.shared.sessionVariables // shellCfg.shared.sessionVariables;

  mergedSessionPath = unique (
    config.homeModules.shell.shared.sessionPath ++ shellCfg.shared.sessionPath
  );

  toNushellPathLiteral =
    path:
    if hasPrefix "$HOME/" path then "$\"($env.HOME)/${removePrefix "$HOME/" path}\"" else "\"${path}\"";

  additionalPathLiteral = concatMapStringsSep " " toNushellPathLiteral mergedSessionPath;
in
{
  options.myConfig.shell.nushell.enable = mkEnableOption "Nushell configuration";

  config = mkIf nushellEnabled {
    programs.nushell = {
      enable = true;
      shellAliases = config.homeModules.shell.resolvedAliases;
      environmentVariables = mergedSessionVariables;
      extraEnv = ''
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

        ${config.homeModules.shell.shared.nushellEnv}
        ${shellCfg.shared.nushellEnv}
      '';
      extraConfig = ''
        $env.config.history = {
            file_format: "sqlite"
            isolation: true
        }

        ${config.homeModules.shell.shared.nushellConfig}
        ${shellCfg.shared.nushellConfig}
      '';
    };
  };
}
