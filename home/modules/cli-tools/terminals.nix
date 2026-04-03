{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:

with lib;

let
  cfg = config.myConfig.cliTools.terminals;

  mkEnable = myLib.mkEnableOption' cfg.enableAll;
in
{
  options.myConfig.cliTools.terminals = {
    enableAll = mkOption {
      type = types.bool;
      default = false;
      description = "Enable all terminal tools (can be overridden per-tool)";
    };

    bmux.enable = mkEnable "Bmux terminal multiplexer";
    zellij.enable = mkEnable "Zellij terminal workspace";
    tmux.enable = mkEnable "Tmux terminal multiplexer";
    wezterm.enable = mkEnable "WezTerm terminal emulator";

    ghostty = {
      enable = mkEnable "Ghostty terminal emulator";
      hideWindowDecoration = mkOption {
        type = types.bool;
        default = false;
        description = "Hide window titlebar/decoration (recommended for tiling WMs)";
      };
    };
  };

  config = {
    # Bmux
    xdg.configFile."bmux/bmux.toml" = mkIf cfg.bmux.enable {
      text = ''
        [general]
        default_shell = "${pkgs.fish}/bin/fish"

      ''
      + builtins.readFile ../../../configs/bmux/bmux.toml;
    };

    # Zellij - use custom package when available
    programs.zellij = mkIf cfg.zellij.enable {
      enable = true;
      package = pkgs.zellij-custom or pkgs.zellij;
    };
    xdg.configFile."zellij/config.kdl" = mkIf cfg.zellij.enable {
      source = ../../../configs/zellij/config.kdl;
    };

    # Tmux
    programs.tmux = mkIf cfg.tmux.enable {
      enable = true;
      extraConfig = builtins.readFile ../../../configs/tmux/tmux.conf;
    };

    # WezTerm
    programs.wezterm = mkIf cfg.wezterm.enable {
      enable = true;
      extraConfig = builtins.readFile ../../../configs/wezterm/wezterm.lua;
    };

    # Ghostty - read base config from file and append host-specific overrides
    xdg.configFile."ghostty/config" = mkIf cfg.ghostty.enable {
      text =
        builtins.readFile ../../../configs/ghostty/config
        + optionalString cfg.ghostty.hideWindowDecoration ''

          # Host-specific: Hide window decoration for tiling WM
          window-decoration = false
        '';
    };
  };
}
