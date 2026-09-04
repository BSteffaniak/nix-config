{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.containers.docker-cli;
in
{
  options.myConfig.containers.docker-cli = {
    enable = lib.mkEnableOption "Docker CLI tools (can connect to Docker daemon or Podman)";

    includeCompose = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include docker-compose";
    };

    includeBuildx = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include docker buildx for advanced builds";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        docker-client
      ]
      ++ (lib.optional cfg.includeCompose docker-compose)
      ++ (lib.optional cfg.includeBuildx docker-buildx);

    # Docker completions shared across configured shells
    myConfig.shell.contrib.completionCommands = [ "docker" ];
  };
}
