{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  options.myConfig.services.docker = {
    enable = mkEnableOption "Docker container runtime";
    dataRoot = mkOption {
      type = types.str;
      default = "/var/lib/docker";
      description = "Docker data root directory";
    };
  };

  config = mkIf config.myConfig.services.docker.enable {
    virtualisation.docker = {
      enable = true;
      # docker_28 (the nixpkgs default) is marked insecure in 25.11.
      package = pkgs.docker_29;
      daemon.settings = {
        data-root = config.myConfig.services.docker.dataRoot;
      };
    };
  };
}
