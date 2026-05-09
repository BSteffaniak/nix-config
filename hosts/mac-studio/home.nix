# Personal home-manager overrides for mac-studio host
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
    # Desktop - AeroSpace tiling window manager
    desktop.aerospace.enable = true;
    desktop.sketchybar.enable = true;
    desktop.hex.enable = true;
    desktop.mkalias.enable = true;
    desktop.sledge.enable = true;
    desktop.utilities.bitwarden.enable = true;
    desktop.wallpaper.enable = true;

    # CLI tools - now configured directly in home-manager
    cliTools = {
      terminals.bmux.enable = true;
      terminals.ghostty = {
        enable = true;
        hideWindowDecoration = true;
      };
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
      utilities.opencodeUpstream.enable = true;
      utilities.sshenv.enable = true;
      utilities.clippier.enable = true;
      utilities.worktree-setup.enable = true;
    };

    # Development tool configs
    development.lazygit.enable = true;
    development.act.enable = true;
    development.opencode.enable = true;
    development.opencode.aliases.openai-api = {
      provider = "openai";
      sshenvProfile = "openai-api";
      ignorePersistedAuth = true;
    };
    development.opencode.aliases.openrouter = {
      provider = "openrouter";
      sshenvProfile = "openrouter";
      ignorePersistedAuth = true;
    };
    development.opencode.aliases.grok-4-3 = {
      provider = "grok-4.3";
      sshenvProfile = "xai";
      ignorePersistedAuth = true;
    };
    development.opencode.aliases.grok-code-fast = {
      provider = "grok-code-fast";
      sshenvProfile = "xai";
      ignorePersistedAuth = true;
    };
    development.opencode.permissions.restricted = [
      "git"
      "brew"
    ];
    development.brouter = {
      enable = true;
      makePiDefault = true;
      openaiMax.enable = true;
      openrouter.enable = true;
      opencodeZen.enable = true;
    };
    development.pi.enable = true;
    development.lspmux.enable = true;

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
      ai.ollama = {
        enable = true;
        model = "qwen3:30b-a3b";
        extraModels = [ "qwen3:14b" ];
        modelsToPull = [
          "qwen3:30b-a3b"
          "qwen3:14b"
        ];
      };
      tts.piper.enable = true;
    };
  };
}
