{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.containers.podman;
in
{
  options.myConfig.containers.podman = {
    enable = lib.mkEnableOption "Rootless Podman container runtime";

    dockerCompatibility = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Docker CLI compatibility by setting DOCKER_HOST";
    };

    composeEnable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install podman-compose for docker-compose compatibility";
    };

    suppressComposeWarning = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Suppress the external compose provider warning message";
    };

    autoUpdate = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable automatic container updates via systemd timer";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        podman
      ]
      ++ (lib.optional cfg.composeEnable podman-compose);

    # Set up rootless podman storage configuration
    xdg.configFile."containers/storage.conf".text = ''
      [storage]
      driver = "overlay"
      runroot = "$HOME/.local/share/containers/storage"
      graphroot = "$HOME/.local/share/containers/storage"

      ${lib.optionalString pkgs.stdenv.isLinux ''
        [storage.options.overlay]
        mount_program = "${pkgs.fuse-overlayfs}/bin/fuse-overlayfs"
      ''}
    '';

    # Configure container registries
    xdg.configFile."containers/registries.conf".text = ''
      unqualified-search-registries = ["docker.io", "quay.io", "ghcr.io"]

      [[registry]]
      prefix = "docker.io"
      location = "docker.io"
    '';

    # Podman engine configuration
    xdg.configFile."containers/containers.conf" = lib.mkIf cfg.suppressComposeWarning {
      text = ''
        [engine]
        compose_warning_logs = false
      '';
    };

    # Docker compatibility - set DOCKER_HOST to point to podman socket
    # On Linux, the socket is managed by the systemd user service below
    # On macOS, podman machine exposes an API socket under $TMPDIR
    home.sessionVariables = lib.mkIf cfg.dockerCompatibility {
      DOCKER_HOST =
        if pkgs.stdenv.isDarwin then
          "unix://$TMPDIR/podman/podman-machine-default-api.sock"
        else
          "unix://$XDG_RUNTIME_DIR/podman/podman.sock";
    };

    # Enable podman socket as a user service (Linux only)
    systemd.user.services.podman-socket = lib.mkIf pkgs.stdenv.isLinux {
      Unit = {
        Description = "Podman API Socket";
        Documentation = "man:podman-system-service(1)";
      };
      Service = {
        Type = "exec";
        ExecStart = "${pkgs.podman}/bin/podman system service --time=0 unix://%t/podman/podman.sock";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };

    # Auto-update containers (optional)
    systemd.user.services.podman-auto-update = lib.mkIf (cfg.autoUpdate && pkgs.stdenv.isLinux) {
      Unit = {
        Description = "Podman Auto-Update";
        Documentation = "man:podman-auto-update(1)";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.podman}/bin/podman auto-update";
      };
    };

    systemd.user.timers.podman-auto-update = lib.mkIf (cfg.autoUpdate && pkgs.stdenv.isLinux) {
      Unit = {
        Description = "Podman Auto-Update Timer";
      };
      Timer = {
        OnCalendar = "daily";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };

    # Podman completions shared across configured shells
    myConfig.shell.contrib.completionCommands = [ "podman" ];
  };
}
