{
  # Host type: "nixos", "darwin", or "home-manager"
  type = "nixos";
  # Nix system identifier
  system = "x86_64-linux";
  # Hostname as reported by `hostname` (used by rebuild.sh for auto-detection)
  hostname = "nixos";
  # Primary username for this host
  username = "braden";
  # Extra flake inputs to include as NixOS modules
  extraModules = [ "nix-minecraft" ];
}
