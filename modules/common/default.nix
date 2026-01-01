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
      default = "braden";
      description = "Primary username";
    };

    fullName = lib.mkOption {
      type = lib.types.str;
      default = "Braden Steffaniak";
      description = "Full name for user";
    };

    homeManagerStateVersion = lib.mkOption {
      type = lib.types.str;
      default = "25.05";
      description = "Home Manager state version";
    };
  };

  config = {
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
