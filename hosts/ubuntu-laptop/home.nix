# Ubuntu Laptop - Standalone Home Manager Configuration
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../../home/standalone
    ../../home/standalone/ubuntu.nix
  ];

  # User info
  home.username = "braden";
  home.homeDirectory = "/home/braden";
  home.stateVersion = "25.05";

  # Enable all the development tools and features
  myConfig = {
    # Development environments
    development.rust.enable = true;
    development.rust.includeNightly = true;
    development.nodejs.enable = true;
    development.go.enable = true;
    development.python.enable = true;
    development.zig.enable = true;
    development.opencode.enable = true;

    # Containers - rootless!
    containers.podman.enable = true;
    containers.podman.dockerCompatibility = true;
    containers.podman.composeEnable = true;
    containers.tools.enable = true;

    # DevOps tools
    devops.kubernetes.enable = true;
    devops.cloud.enable = true;
    devops.infrastructure.enable = true;

    # Shell configuration
    shell.fish.enable = true;
    shell.git.enable = true;
    shell.ssh.enable = true;

    # Editors
    editors.neovim.enable = true;
    editors.neovim.useNightly = true;

    # CLI Tools - granular enables (no system-level on Ubuntu standalone)
    cliTools = {
      terminals.zellij.enable = true;
      terminals.tmux.enable = true;
      terminals.wezterm.enable = true;
      terminals.ghostty.enable = true;

      monitoring.bottom.enable = true;
      monitoring.htop.enable = true;

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
  };

  # Ubuntu laptop specific packages
  home.packages = with pkgs; [
    # Add any laptop-specific tools here
  ];
}
