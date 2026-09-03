{
  # Host type: "nixos", "darwin", or "home-manager"
  type = "nixos";
  # Nix system identifier
  system = "x86_64-linux";
  # Hostname as reported by `hostname` (used by rebuild.sh for auto-detection)
  hostname = "nixos";
  # Primary username for this host
  username = "braden";
  # NixOS release this system was first installed with (system.stateVersion)
  stateVersion = "24.11";
  # Home Manager release first used on this host (home.stateVersion)
  homeStateVersion = "24.11";
  # Extra named modules/overlays to include (see lib/hosts.nix extraModuleMap)
  extraModules = [ "nix-minecraft" ];
}
