{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common
    ../../modules/nixos
  ];

  # Sledge owns user tooling in Home Manager; the system only registers its
  # ordered login entry. Ordinary Hyprland stays available as recovery.
  services.displayManager = lib.mkIf config.home-manager.users.braden.myConfig.desktop.sledge.enable {
    sessionPackages = [ config.home-manager.users.braden.programs.sledgeHyprland.sessionPackage ];
    defaultSession = "hyprland-sledge";
  };

  # Bound daemon build concurrency separately from interactive Cargo jobs.
  nix.settings = {
    max-jobs = 2;
    cores = 2;
  };

  # Keep temporary build/test files off the root disk. Deploy with a boot
  # rebuild and reboot, rather than mounting over a live /tmp.
  boot.tmp.useTmpfs = false;

  fileSystems."/tmp" = {
    device = "/hdd/tmp";
    fsType = "none";
    depends = [ "/hdd" ];
    options = [
      "bind"
      "x-systemd.requires=hdd-tmp-directory.service"
    ];
  };

  # Normal tmpfiles setup runs after local mounts, so provision the bind
  # source separately before tmp.mount, and only after /hdd is mounted.
  systemd.services.hdd-tmp-directory = {
    description = "Prepare temporary directory on /hdd";
    requires = [ "hdd.mount" ];
    after = [ "hdd.mount" ];
    before = [ "tmp.mount" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/install -d -m 1777 -o root -g root /hdd/tmp";
    };
  };

  # Host-specific system settings. User tools live in home.nix.
  myConfig = {
    # Boot configuration
    boot.enable = true;
    boot.useLatestKernel = false;

    # Hardware
    hardware.nvidia.enable = true;
    hardware.graphics.enable = true;

    # Desktop environment
    desktop.hyprland = {
      enable = true;
      # Host-specific monitor and workspace configuration
      monitorsConfig = ./hyprland/monitors.conf;
      workspacesConfig = ./hyprland/workspaces.conf;
    };
    desktop.hex.enableInputAccess = true;
    desktop.waybar.enable = true;
    desktop.gtk.enable = true;
    desktop.xserver.enable = true;

    # Login shells
    shell.fish.enable = true;
    shell.bash.enable = true;
    shell.zsh.enable = true;
    shell.nushell.enable = true;

    # Services
    services.sshd.enable = true;
    services.avahi.enable = true;
    services.docker.enable = true;
    services.docker.dataRoot = "/hdd/docker";
    services.observability.enable = true;
    services.minecraft.enable = true;

    # System configuration
    system.networking.enable = true;
    system.security.enable = true;
    system.memoryPressure.enable = true;
    system.audio.enable = true;
    system.locale.enable = true;
    system.locale.timeZone = "America/New_York";
  };

  # A separate, fresh world; Greenfield retains its existing package and data.
  services.minecraft-servers.servers.new-dc = {
    enable = true;
    autoStart = false;
    # Source-restricted rules below, rather than globally opening these ports.
    openFirewall = false;

    package = pkgs.paperServers.paper.override {
      version = "26.3-build.227";
      url = "https://fill-data.papermc.io/v1/objects/416b7d105b1d0192df4afa4b29d2800d9dbeda092a82fbc5b511248a54adde15/paper-26.3-227.jar";
      sha256 = "416b7d105b1d0192df4afa4b29d2800d9dbeda092a82fbc5b511248a54adde15";
    };

    serverProperties = {
      server-port = 25566;
      level-name = "world";
      level-seed = "";
      gamemode = "survival";
      difficulty = "normal";
      max-players = 20;
      view-distance = 10;
      simulation-distance = 10;
      motd = "New DC - Java & Bedrock Crossplay";
      white-list = true;
      online-mode = true;
      # Floodgate players do not have Java profile signing keys.
      enforce-secure-profile = false;
    };

    whitelist = config.services.minecraft-servers.servers.greenfield.whitelist;
    symlinks = {
      "plugins/GeyserMC.jar" = pkgs.minecraftPlugins.geysermc-stable;
      "plugins/Floodgate.jar" = pkgs.minecraftPlugins.floodgate;
      "plugins/ViaVersion.jar" = pkgs.minecraftPlugins.viaversion-stable;
      "plugins/ViaBackwards.jar" = pkgs.minecraftPlugins.viabackwards;
    };
    # Copy a writable config: Geyser fills defaults and migrates it on startup.
    files."plugins/Geyser-Spigot/config.yml".value = {
      config-version = 9;
      bedrock = {
        address = "0.0.0.0";
        port = 19133;
        # Keep RakNet for older supported Bedrock clients and NetherNet for
        # current clients. Each transport needs a distinct UDP listener.
        transport = "both";
        webrtc-port = 19134;
        signaling.stun-discovery = false;
        clone-remote-port = false;
      };
      java.auth-type = "floodgate";
    };
  };

  # Geyser's NetherNet JNI library dynamically loads OpenSSL by soname.
  systemd.services.minecraft-server-new-dc.environment.LD_LIBRARY_PATH = lib.makeLibraryPath [
    pkgs.openssl
  ];

  # Permit New DC only from private IPv4 LAN/VPN source ranges. Public IPv4
  # and IPv6 remain closed; add explicit VPN ranges here if needed later.
  networking.firewall.extraCommands =
    lib.concatMapStringsSep "\n"
      (subnet: ''
        iptables -A nixos-fw -s ${subnet} -p tcp -m multiport --dports 25566,19133 -j nixos-fw-accept
        iptables -A nixos-fw -s ${subnet} -p udp -m multiport --dports 19133,19134 -j nixos-fw-accept
      '')
      [
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
      ];
  networking.firewall.extraStopCommands =
    lib.concatMapStringsSep "\n"
      (subnet: ''
        iptables -D nixos-fw -s ${subnet} -p tcp -m multiport --dports 25566,19133 -j nixos-fw-accept 2>/dev/null || true
        iptables -D nixos-fw -s ${subnet} -p udp -m multiport --dports 19133,19134 -j nixos-fw-accept 2>/dev/null || true
      '')
      [
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
      ];

  # User configuration
  users.users.${config.myConfig.username} = {
    isNormalUser = true;
    description = "Braden Steffaniak";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
    packages = with pkgs; [
      signal-desktop
      telegram-desktop
      discord
      microsoft-edge
      fuseiso
      udiskie
      xclip
      xsel
      lshw
      pciutils
      usbutils
      slurm-nm
      acpi
    ];
  };

  # System packages specific to this host
  environment.systemPackages = with pkgs; [
    inputs.home-manager.packages."${pkgs.stdenv.hostPlatform.system}".default
    unstable.bpftools
    unstable.nftables
    unstable.wl-clipboard
  ];

  # Fonts
  fonts = {
    packages = with pkgs; [
      font-awesome
      fira-code
      fira-code-symbols
      nerd-fonts.fira-code
    ];
  };

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
}
