# Personal home-manager overrides for nixos-desktop host
# Contains personal preferences and should not be copied when bootstrapping new hosts
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Enable GTK theming with personal preferences
  homeModules.gtkTheming = {
    enable = true;
    theme = "Juno";
    themePackage = pkgs.juno-theme;
    iconTheme = "Papirus-Dark";
    iconThemePackage = pkgs.papirus-icon-theme;
    cursorTheme = "Bibata-Modern-Classic";
    cursorThemePackage = pkgs.bibata-cursors;
    font = {
      name = "TeX Gyre Adventor";
      size = 10;
    };
  };

  # Fish shell - feature-based configuration
  homeModules.fish = {
    # Flat Project (includes logging and airship)
    flat = {
      enable = true;
      logging = true;
      airship = true;
    };

    # Zellij
    zellij = {
      enable = true;
      resurrect = true;
    };

    # Development Tools
    development = {
      enable = true;
      benchmark = true;
    };
  };

  # Enable standalone config modules
  myConfig = {
    # CLI tools - now configured directly in home-manager
    cliTools = {
      terminals.zellij.enable = true;
      terminals.tmux.enable = true;

      monitoring.bottom.enable = true;
      monitoring.htop.enable = true;
      monitoring.ncdu.enable = true;
      monitoring.bandwhich.enable = true;
      monitoring.nethogs.enable = true;

      fileTools.fzf.enable = true;
      fileTools.ripgrep.enable = true;
      fileTools.fd.enable = true;
      fileTools.unzip.enable = true;
      fileTools.zip.enable = true;

      formatters.nixfmt.enable = true;
      formatters.eslint.enable = true;
      formatters.prettier.enable = true;
      formatters.taplo.enable = true;

      utilities.direnv.enable = true;
      utilities.jq.enable = true;
      utilities.parallel.enable = true;
      utilities.write-good.enable = true;
      utilities.cronstrue.enable = true;
      utilities.cloc.enable = true;
      utilities.watchexec.enable = true;
      utilities.lsof.enable = true;
      utilities.killall.enable = true;
      utilities.nix-search.enable = true;
      utilities.media.ffmpeg.enable = true;
      utilities.media.flac.enable = true;
      utilities.media.mediainfo.enable = true;
      utilities.opencode.enable = true;
    };

    # Development tool configs
    development.lazygit.enable = true;
    development.act.enable = true;
    development.opencode.enable = true;
    development.ra-multiplex.enable = true;

    # DevOps tool configs
    devops.github.enable = true;

    # Desktop utility configs
    desktop.utilities = {
      enable = true;
      wallpaperFolder = "/hdd/wallpapers";
      defaultWallpaper = "pexels-pok-rie-33563-982263.jpg";
    };

    # Neovim plugin configuration
    editors.neovim.plugins = {
      supermaven = true; # Enable Supermaven AI assistant
      copilot = false; # Disable GitHub Copilot (use Supermaven instead)
      avante = false; # Disable Avante (heavier AI assistant)
      jdtls = true; # Enable Java development tools
      elixir = true; # Enable Elixir plugins
      ionide = true; # Enable F# support
      dadbod = true; # Enable database tools
      treesitterHypr = true; # Enable Hyprland tree-sitter (for NixOS desktop)
    };
  };

  # Personal packages
  home.packages = with pkgs; [
    steam
    opencode-dev
    unstable.gemini-cli
  ];
}
