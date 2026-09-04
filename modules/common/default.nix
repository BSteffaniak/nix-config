{
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./services
    ./shell.nix
  ];

  # Options shared by every system configuration. User-facing feature flags
  # live in home-manager (home/modules); only system concerns are declared here.
  options.myConfig = {
    username = lib.mkOption {
      type = lib.types.str;
      description = "Primary username";
    };

    fullName = lib.mkOption {
      type = lib.types.str;
      default = "Braden Steffaniak";
      description = "Full name for user";
    };
  };

  config = {
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Baseline packages for all platforms
    environment.systemPackages = with pkgs; [
      vim
      wget
      clang
      glib
      nvd
    ];
  };
}
