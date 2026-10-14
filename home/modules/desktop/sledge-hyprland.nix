# Linux branch kept separate from Darwin signing/LaunchAgent behavior.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.myConfig.desktop.sledge;
  source = cfg.hyprland.source;
  approved = builtins.fromJSON (builtins.readFile ../../../configs/sledge/hyprland/contract.json);
  toolchain = pkgs.rust-bin.fromRustupToolchainFile (source + "/rust-toolchain.toml");
  qualified = import (source + "/packaging/linux/hyprland/qualified.nix") {
    inherit pkgs;
    rustPlatform = pkgs.makeRustPlatform {
      cargo = toolchain;
      rustc = toolchain;
    };
    contract = approved // {
      compositor_path = "${pkgs.hyprland}/bin/.Hyprland-wrapped";
    };
    evidence = ../../../configs/sledge/hyprland/evidence.json;
    acceptance = ../../../configs/sledge/hyprland/acceptance.json;
  };
  original = builtins.readFile ../../../configs/hyprland/hyprland.conf;
  lines = lib.splitString "\n" original;
  autostart = lib.filter (line: lib.hasPrefix "exec-once" (lib.strings.trim line)) lines;
  commands = map (
    line:
    lib.replaceStrings [ "~/" ] [ "${config.home.homeDirectory}/" ] (
      lib.strings.trim (
        lib.removePrefix "=" (lib.strings.trim (lib.removePrefix "exec-once" (lib.strings.trim line)))
      )
    )
  ) autostart;
  compositorConfig = lib.concatStringsSep "\n" (
    lib.filter (line: !lib.hasPrefix "exec-once" (lib.strings.trim line)) lines
  );
in
{
  imports = [ (inputs.sledge-hyprland-src + "/packaging/linux/hyprland/home-module.nix") ];
  options.myConfig.desktop.sledge.hyprland.source = lib.mkOption {
    type = lib.types.path;
    default = inputs.sledge-hyprland-src;
    description = "Exact reviewed Sledge checkout; source changes invalidate qualification.";
  };
  config = lib.mkIf (cfg.enable && pkgs.stdenv.isLinux) {
    assertions = [
      {
        assertion = config.myConfig.desktop.hyprland.enable;
        message = "Sledge's Linux backend requires the Hyprland configuration.";
      }
    ];
    xdg.configFile."sledge/config.toml".source = ../../../configs/sledge/config.toml;
    programs.sledgeHyprland = {
      enable = true;
      bundle = qualified.bundle;
      # Runtime reads the same user-facing file installed above.
      configFile = null;
      firstApp = [ "${pkgs.ghostty}/bin/ghostty" ];
      inherit compositorConfig;
      autostartCommands =
        lib.filter (command: command != "$terminal") commands
        ++ lib.optional (
          config.myConfig.desktop.hex.enable && config.myConfig.desktop.hex.openOnLogin
        ) "${lib.getExe config.programs.hex.package} start";
    };
    # NixOS registers sessionPackage with GDM and selects it by default.
    # Ordinary Hyprland remains the recovery entry.
  };
}
