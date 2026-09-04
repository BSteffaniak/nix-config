{ pkgs, ... }:

{
  imports = [
    ./aerospace.nix
    ./applications.nix
    ./awake.nix
    ./casks.nix
    ./cloudflare-warp.nix
    ./homebrew.nix
    ./keepingyouawake.nix
    ./minecraft.nix
    ./ollama.nix
    ./scroll-reverser.nix
    ./security.nix
    ./sketchybar.nix
    ./ssh.nix
    ./system-defaults.nix
    ./system-limits.nix
    ./tailscale.nix
  ];

  nix.package = pkgs.nix;
}
