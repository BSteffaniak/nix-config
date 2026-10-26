{
  config,
  lib,
  ...
}:

{
  imports = [
    ./networking.nix
    ./security.nix
    ./audio.nix
    ./locale.nix
    ./shell.nix
    ./ssh.nix
  ];

  options.myConfig.system.memoryPressure.enable =
    lib.mkEnableOption "early memory-pressure recovery for development desktops";

  config = lib.mkIf config.myConfig.system.memoryPressure.enable {
    # Use one userspace OOM policy. Merely running oomd without enabling its
    # monitored slices does not protect the desktop; killing an entire user
    # cgroup is also too coarse for interactive builds mixed with user services.
    systemd.oomd.enable = false;

    services.earlyoom = {
      enable = true;
      # Both available RAM and free swap must cross their thresholds.
      # Leave headroom for recovery rather than waiting for kernel OOM kills.
      freeMemThreshold = 10;
      freeSwapThreshold = 20;
      freeMemKillThreshold = 5;
      freeSwapKillThreshold = 10;
      extraArgs = [
        # Match /proc/PID/comm, not command lines. These are preferences,
        # not exemptions or a global Cargo concurrency limit.
        "--prefer"
        "^(rustc|ld|ld\\.bfd|ld\\.gold|ld\\.lld|rust-lld|cc1|cc1plus)$"
        "--avoid"
        "^(systemd|dbus-daemon|dbus-broker|Hyprland|\\.Hyprland-wrapp|sledge|pipewire|pipewire-pulse|wireplumber)$"
      ];
    };
  };
}
