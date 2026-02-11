{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.containers.podman;
in
{
  options.myConfig.containers.podman = {
    enable = mkEnableOption "Rootless Podman container runtime";

    dockerCompatibility = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Docker CLI compatibility by setting DOCKER_HOST";
    };

    composeEnable = mkOption {
      type = types.bool;
      default = true;
      description = "Install podman-compose for docker-compose compatibility";
    };

    suppressComposeWarning = mkOption {
      type = types.bool;
      default = true;
      description = "Suppress the external compose provider warning message";
    };

    autoUpdate = mkOption {
      type = types.bool;
      default = false;
      description = "Enable automatic container updates via systemd timer";
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        podman
      ]
      ++ (optional cfg.composeEnable podman-compose);

    # Set up rootless podman storage configuration
    xdg.configFile."containers/storage.conf".text = ''
      [storage]
      driver = "overlay"
      runroot = "$HOME/.local/share/containers/storage"
      graphroot = "$HOME/.local/share/containers/storage"

      ${optionalString pkgs.stdenv.isLinux ''
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
    xdg.configFile."containers/containers.conf" = mkIf cfg.suppressComposeWarning {
      text = ''
        [engine]
        compose_warning_logs = false
      '';
    };

    # Docker compatibility - set DOCKER_HOST to point to podman socket (Linux only)
    # On macOS, podman compose connects to the machine via SSH natively
    # and DOCKER_HOST is not needed (XDG_RUNTIME_DIR is unset on Darwin)
    home.sessionVariables = mkIf (cfg.dockerCompatibility && pkgs.stdenv.isLinux) {
      DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/podman/podman.sock";
    };

    # Enable podman socket as a user service (Linux only)
    systemd.user.services.podman-socket = mkIf pkgs.stdenv.isLinux {
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
    systemd.user.services.podman-auto-update = mkIf (cfg.autoUpdate && pkgs.stdenv.isLinux) {
      Unit = {
        Description = "Podman Auto-Update";
        Documentation = "man:podman-auto-update(1)";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.podman}/bin/podman auto-update";
      };
    };

    systemd.user.timers.podman-auto-update = mkIf (cfg.autoUpdate && pkgs.stdenv.isLinux) {
      Unit = {
        Description = "Podman Auto-Update Timer";
      };
      Timer = {
        OnCalendar = "daily";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };

    # Fish shell completions
    programs.fish.interactiveShellInit = mkIf config.programs.fish.enable ''
      # Podman completions
      podman completion fish | source
    '';
  };
}
