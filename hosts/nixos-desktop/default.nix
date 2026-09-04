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
    services.tailscale.enable = true;

    # System configuration
    system.networking.enable = true;
    system.security.enable = true;
    system.audio.enable = true;
    system.locale.enable = true;
    system.locale.timeZone = "America/New_York";
  };

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
      kitty
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
