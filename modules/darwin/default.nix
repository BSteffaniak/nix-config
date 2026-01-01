{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./applications.nix
    ./homebrew.nix
    ./ssh.nix
    ./system-defaults.nix
    ./tailscale.nix
  ];

  config = {
    # Enable experimental features
    nix = {
      package = pkgs.nix;
      settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
    };

    # Enable fish shell
    programs.fish.enable = true;
  };
}
