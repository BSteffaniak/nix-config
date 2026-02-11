{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  options.myConfig.development.podman = {
    enable = mkEnableOption "Podman container runtime";
  };

  config = mkIf config.myConfig.development.podman.enable {
    environment.systemPackages = with pkgs; [
      podman
    ];

    # Set DOCKER_HOST to point to podman socket (Linux only)
    # On macOS, podman compose connects to the machine via SSH natively
    # and DOCKER_HOST is not needed
    environment.variables = mkIf pkgs.stdenv.isLinux {
      DOCKER_HOST = "unix://$HOME/.local/share/containers/podman/machine/podman.sock";
    };
  };
}
