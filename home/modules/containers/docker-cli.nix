{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.containers.docker-cli;
in
{
  options.myConfig.containers.docker-cli = {
    enable = mkEnableOption "Docker CLI tools (can connect to Docker daemon or Podman)";

    includeCompose = mkOption {
      type = types.bool;
      default = true;
      description = "Include docker-compose";
    };

    includeBuildx = mkOption {
      type = types.bool;
      default = true;
      description = "Include docker buildx for advanced builds";
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        docker-client
      ]
      ++ (optional cfg.includeCompose docker-compose)
      ++ (optional cfg.includeBuildx docker-buildx);

    # Docker completions shared across configured shells
    homeModules.shell.shared.completionCommands = [ "docker" ];
  };
}
