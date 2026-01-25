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
    inputs.nix-minecraft.nixosModules.minecraft-servers
    ../../modules/nixos/services/minecraft.nix
  ];

  # Host-specific settings
  myConfig = {
    username = "braden";
    fullName = "Braden Steffaniak";

    # Boot configuration
    boot.enable = true;
    boot.useLatestKernel = false;

    # Hardware
    hardware.nvidia.enable = true;
    hardware.graphics.enable = true;

    # Desktop environment
    desktop.enable = true;
    desktop.hyprland = {
      enable = true;
      # Host-specific monitor and workspace configuration
      monitorsConfig = ./hyprland/monitors.conf;
      workspacesConfig = ./hyprland/workspaces.conf;
    };
    desktop.waybar.enable = true;
    desktop.gtk.enable = true;
    desktop.xserver.enable = true;

    # Development tools
    development.rust.enable = true;
    development.rust.includeNightly = true;
    development.nodejs.enable = true;
    development.go.enable = true;
    development.python.enable = true;
    development.android.enable = true;
    development.devops.enable = true;
    development.zig.enable = true;
    development.openssl.enable = true;

    # Shell and editors
    shell.fish.enable = true;
    shell.git.enable = true;
    shell.ssh.enable = true;
    shell.ssh.server.enable = true;
    editors.neovim.enable = true;
    editors.neovim.useNightly = true;

    # Services
    services.docker.enable = true;
    services.docker.dataRoot = "/hdd/docker";
    services.observability.enable = true;
    services.minecraft.enable = true;
    services.tailscale.enable = true;

    # System configuration
    system.enable = true;
    system.networking.enable = true;
    system.networking.hostName = "nixos";
    system.security.enable = true;
    system.audio.enable = true;
    system.locale.enable = true;
    system.locale.timeZone = "America/New_York";
  };

  # User configuration
  users.users.braden = {
    isNormalUser = true;
    description = "Braden Steffaniak";
    shell = pkgs.fish;
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

  users.defaultUserShell = pkgs.fish;

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

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11";
}
