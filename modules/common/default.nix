{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  imports = [
    ./development
    ./editors
    ./services
    ./shell
  ];

  # Common options available on all platforms
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

    # Common packages for all platforms
    environment.systemPackages = with pkgs; [
      vim
      wget
      clang
      glib
      nvd
    ];
  };
}
