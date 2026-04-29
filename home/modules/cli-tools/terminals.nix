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
  shellCfg = config.myConfig.shell;

  mkEnable = myLib.mkEnableOption' cfg.enableAll;

  defaultShellPackages = {
    fish = pkgs.fish;
    bash = pkgs.bashInteractive;
    zsh = pkgs.zsh;
    nushell = pkgs.nushell;
  };

  defaultShellBinaries = {
    fish = "fish";
    bash = "bash";
    zsh = "zsh";
    nushell = "nu";
  };

  defaultShellPath = "${defaultShellPackages.${shellCfg.default}}/bin/${
    defaultShellBinaries.${shellCfg.default}
  }";

  ghosttyTerminfo =
    if pkgs.stdenv.hostPlatform.isDarwin then pkgs.ghostty-bin.terminfo else pkgs.ghostty.terminfo;

  installGhosttyTerminfo = cfg.ghostty.enable || cfg.ghostty.installTerminfo;
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
      installTerminfo = mkOption {
        type = types.bool;
        default = false;
        description = "Install Ghostty's xterm-ghostty terminfo entry without enabling the Ghostty config";
      };
    };
  };

  config = {
    home.packages = mkMerge [
      (mkIf cfg.bmux.enable [ pkgs.bmux ])
      (mkIf installGhosttyTerminfo [ ghosttyTerminfo ])
    ];

    home.file = mkIf installGhosttyTerminfo {
      ".terminfo/78/xterm-ghostty".source = "${ghosttyTerminfo}/share/terminfo/78/xterm-ghostty";
      ".terminfo/67/ghostty".source = "${ghosttyTerminfo}/share/terminfo/67/ghostty";
    };

    # Bmux
    xdg.configFile."bmux/bmux.toml" = mkIf cfg.bmux.enable {
      text = ''
        [general]
        default_shell = "${defaultShellPath}"

      ''
      + builtins.readFile ../../../configs/bmux/bmux.toml;
    };

    # Zellij - use custom package when available
    programs.zellij = mkIf cfg.zellij.enable {
      enable = true;
      package = pkgs.zellij-custom or pkgs.zellij;
    };
    xdg.configFile."zellij/config.kdl" = mkIf cfg.zellij.enable {
      text =
        builtins.replaceStrings [ "default_shell \"fish\"" ] [ "default_shell \"${defaultShellPath}\"" ]
          (builtins.readFile ../../../configs/zellij/config.kdl);
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
