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

    # Set DOCKER_HOST to point to podman socket
    # On Linux, uses the podman machine socket under $HOME
    # On macOS, podman machine exposes an API socket under $TMPDIR
    environment.variables = {
      DOCKER_HOST =
        if pkgs.stdenv.isDarwin then
          "unix://$TMPDIR/podman/podman-machine-default-api.sock"
        else
          "unix://$HOME/.local/share/containers/podman/machine/podman.sock";
    };
  };
}
