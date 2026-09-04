{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.myConfig.services.docker = {
    enable = lib.mkEnableOption "Docker container runtime";
    dataRoot = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/docker";
      description = "Docker data root directory";
    };
  };

  config = lib.mkIf config.myConfig.services.docker.enable {
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
