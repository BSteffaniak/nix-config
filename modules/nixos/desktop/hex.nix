# Raw event-device access is an explicit system-level security opt-in.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myConfig.desktop.hex;
in
{
  options.myConfig.desktop.hex.enableInputAccess = lib.mkEnableOption ''
    raw input-device access for Hex Wayland hotkeys. This exposes all keyboard
    events and other input devices to every process running as an enabled Hex user
  '';

  config = lib.mkIf cfg.enableInputAccess {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
        message = "Hex input access is only supported on x86_64-linux.";
      }
    ];
    users.users = lib.mapAttrs (_: _: { extraGroups = [ "input" ]; }) (
      lib.filterAttrs (_: home: home.myConfig.desktop.hex.enable) config.home-manager.users
    );
  };
}
