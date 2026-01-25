# Personal home-manager overrides for nixos-desktop host
# Contains personal preferences and should not be copied when bootstrapping new hosts
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Fish shell - feature-based configuration
  homeModules.fish = {
    # Zellij
    zellij = {
      enable = true;
      resurrect = true;
    };
  };

  myConfig = {
    # CLI tools - now configured directly in home-manager
    cliTools = {
      terminals.zellij.enable = true;
      terminals.tmux.enable = true;

      monitoring.bottom.enable = true;
      monitoring.htop.enable = true;
      monitoring.ncdu.enable = true;

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

    shell.ssh = {
      matchBlocks = {
        "github.com" = {
          user = "git";
          identityFile = "~/.ssh/github_rsa";
        };
      };
    };

    # Tools
    tools = {
      archiving.enable = true;
      encryption.enable = true;
    };
  };

  # Personal packages
  home.packages = with pkgs; [
    opencode-dev
  ];
}
